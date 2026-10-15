<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/domain/devices/disk[@type='volume']/@type">
        <xsl:attribute name="type">file</xsl:attribute>
    </xsl:template>
    <xsl:template match="/domain/devices/disk[@type='volume']/source">
        <source file="/var/lib/libvirt/images/{@pool}/{@volume}"/>
    </xsl:template>
</xsl:stylesheet>
