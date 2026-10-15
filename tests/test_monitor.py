import os
import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "monitor.sh"


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.log = self.directory / "syslog"
        self.log.write_text("")
        self.env = dict(os.environ, PATH=f"{self.directory}:{os.environ['PATH']}", SYSLOG_FILE=str(self.log))
        self.stub("systemctl", 'if [ "$1" = show ]; then echo loaded; exit 0; fi; exit 0')
        self.stub("journalctl", 'echo "last journal entry"')

    def stub(self, name, body):
        executable = self.directory / name
        executable.write_text("#!/bin/sh\n" + body + "\n")
        executable.chmod(0o755)

    def run_monitor(self, *arguments):
        return subprocess.run([str(SCRIPT), *arguments], env=self.env, text=True, capture_output=True)

    def test_recent_old_future_and_mixed_timestamps(self):
        now = datetime.now(timezone.utc)
        recent = now - timedelta(minutes=5)
        old = now - timedelta(minutes=65)
        future = now + timedelta(minutes=5)
        local = recent.astimezone().strftime("%b %e %H:%M:%S")
        offset = recent.astimezone(timezone(timedelta(hours=3))).isoformat()
        self.log.write_text(
            f"{recent.isoformat()} host app: ERROR first\n"
            f"{old.isoformat()} host app: error old\n"
            f"{future.isoformat()} host app: error future\n"
            f"{local} host app: failed second\n"
            f"{offset} host app: critical third\n"
            f"{recent.isoformat()} host app: noerrors informational\n"
            "invalid timestamp error\n"
        )
        result = self.run_monitor("docker")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("last hour: 3", result.stdout)

    def test_empty_log(self):
        result = self.run_monitor("docker")
        self.assertEqual(result.returncode, 0)
        self.assertIn("last hour: 0", result.stdout)

    def test_inactive_service_includes_journal(self):
        self.stub("systemctl", 'if [ "$1" = show ]; then echo loaded; exit 0; fi; exit 3')
        result = self.run_monitor("docker")
        self.assertEqual(result.returncode, 1)
        self.assertIn("last journal entry", result.stdout)

    def test_missing_service(self):
        self.stub("systemctl", "echo not-found")
        result = self.run_monitor("unknown")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Service not found", result.stderr)

    def test_unreadable_path(self):
        self.log.unlink()
        result = self.run_monitor("docker")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Cannot read syslog", result.stderr)

    def test_invalid_arguments(self):
        for arguments in [[], ["--help"], ["docker", "extra"], ["$(id)"]]:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_monitor(*arguments).returncode, 2)


if __name__ == "__main__":
    unittest.main()
