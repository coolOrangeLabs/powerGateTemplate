<?xml version="1.0" ?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:wix="http://schemas.microsoft.com/wix/2006/wi">

	<!-- Copy all attributes and elements to the output. -->
	<xsl:output method="xml"
				indent="yes"
				omit-xml-declaration="yes"/>
	<xsl:strip-space elements="*"/>

	<xsl:template match="@* | node()">
		<xsl:copy>
			<xsl:apply-templates select="@* | node()"/>
		</xsl:copy>
	</xsl:template>

	<!-- Create searches for the directories to remove. -->
	<xsl:key name="svn-component"
			 match="wix:Component[contains(wix:File/@Source, '.svn')]"
			 use="@Id" />
	<xsl:key name="svn-directory"
			 match="wix:Directory[contains(@Name,'svn')]"
			 use="@Id" />
	<xsl:key name="xml-component"
			 match="wix:Component[contains(wix:File/@Source, '.xml')]"
			 use="@Id" />
	<xsl:key name="pssym-component"
			 match="wix:Component[contains(wix:File/@Source, '.pssym')]"
			 use="@Id" />
	<xsl:key name="pdb-component"
			 match="wix:Component[contains(wix:File/@Source, '.pdb')]"
			 use="@Id" />

	<!-- Create searches for the assemblies that become deployed to gac and should be removed. -->
	<xsl:key name="coolorange-logging-component"
			 match="wix:Component[contains(wix:File/@Source, 'coolOrange.Logging')]"
			 use="@Id" />
	<xsl:key name="coolorange-licensing-component"
			 match="wix:Component[contains(wix:File/@Source, 'coolOrange.Licensing')]"
			 use="@Id" />
	<xsl:key name="coolorange-utils-ui-component"
			 match="wix:Component[contains(wix:File/@Source, 'coolOrange.Utils.UI')]"
			 use="@Id" />

	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('svn-component', @Id)]" />
	<xsl:template match="*[self::wix:Directory]
						[key('svn-directory', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('xml-component', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('pssym-component', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('pdb-component', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('coolorange-logging-component', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('coolorange-licensing-component', @Id)]" />
	<xsl:template match="*[self::wix:Component or self::wix:ComponentRef]
						[key('coolorange-utils-ui-component', @Id)]" />
</xsl:stylesheet>