# Итоговые проверки: дополнение преподавателя, 15 октября 2026

| Требование | Подтверждённый результат |
|---|---|
| Сначала Ansible | До Terraform Docker настроены группа docker для deployer и firewall 8080 |
| Идемпотентность Ansible | Повторный запуск: ok=19 changed=0 failed=0 unreachable=0 skipped=1 |
| Docker provider | kreuzwerker/docker 4.6.0, основной terraform/main.tf |
| Terraform apply | 4 новых ресурса: image, network, volume, container |
| Отдельная новая сеть | terraform-nginx подключён только к terraform-nginx-net |
| Подключённый том | terraform-nginx-html → /usr/share/nginx/html, read-only |
| Нестандартный HTTP-порт | 172.28.77.10:8080 → nginx:80 |
| curl -i | HTTP/1.1 200 OK, Welcome to nginx! |
| Остальные контейнеры в своей сети | app-app-1 и app-nginx-1 только в app_app_net |
| Состояние контейнеров | Все три healthy |
| Повторный Terraform plan | No changes, exit code 0 |
| Непрерывность Compose | Hello World через HTTP 80 продолжает работать |
| Firewall | От другого источника блокируются SSH, HTTP 80 и HTTP 8080 |
| Мониторинг | Проверены active, inactive и несуществующая служба; 6 тестов прошли |
| Статические проверки | Terraform validate/fmt, Ansible syntax-check, Bash и ShellCheck прошли |
| Публичный репозиторий | GitHub visibility=public |
| Вспомогательная VM | Старый state сохранён в vm/, после переноса plan No changes |

## Файлы доказательств

- ansible-docker-first.txt / ansible-docker-second.txt — настройка перед Terraform и повторный запуск.
- terraform-apply.txt / terraform-state.txt / terraform-no-changes.txt — реальные Docker-ресурсы.
- terraform-curl.txt — HTTP-заголовки и страница нового nginx на 8080.
- docker-isolation.json — выбранные поля docker inspect: сети, тома, публикация портов, health.
- compose-vm.txt / curl-vm.txt — оставшееся окружение Compose на 80.
- firewall-negative.txt — отрицательный сетевой тест внутри гостя.
- images/ — шесть прямых снимков окон xterm с повторно выполненными командами.
- terminal-captures/ — записи реальных терминальных сессий, команды, время и SHA-256 снимков.
- vm-*.txt — результаты вспомогательной инфраструктуры из первоначальной реализации.

## Само-ревью и ограничения

- Основной Terraform теперь соответствует уточнению о Docker provider; vm/ — только вспомогательная локальная среда.
- State, tfvars, приватные ключи и образы VM не включены в Git. Docker provider подключается по SSH с проверкой ключа; не публикуется незащищённый Docker API.
- Deployer уже имеет sudo без пароля по ДЗ; группа docker также предоставляет административный доступ. Это не модель ограниченного непривилегированного пользователя.
- Именованный том создаёт Terraform, а не Ansible. В контейнере он доступен только для чтения; образ nginx заполняет новый том штатными HTML-файлами.
- Ansible обновляет только свою таблицу nftables. Docker-таблицы и Compose-сервисы сохраняются.
- Отрицательный тест проведён через временный интерфейс ens-hwtest с источником 172.29.88.2; это проверка правил гостя, не тест из интернета. Namespace и интерфейс удалены.
- Изображения заменены на прямые снимки настоящего xterm в отдельном Xvfb-экране. Команды выполнены заново; изображения не составлены из сохранённых логов. Все шесть команд завершились с кодом 0; Ansible подтвердил changed=0, HTTP 80/8080 — 200 OK.
- Исторические ошибки Docker Snap и обновления ядра контроллера не исправлялись; рабочий Docker Engine расположен внутри VM.
- Старый тег v0.1.0 сохранён; дополнение выпускается отдельной версией v0.2.0.
