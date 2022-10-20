<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet exclude-result-prefixes="#all" xmlns:nf="http://www.nictiz.nl/functions" xmlns:f="http://hl7.org/fhir" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:util="urn:hl7:utilities" version="2.0" xmlns="" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <!--Import mp specific constants (and package for underlying imports)-->
    <xsl:import href="https://raw.githubusercontent.com/Nictiz/HL7-mappings/MP920/ada_2_fhir-r4/mp/9.2.0/payload/mp_latest_package.xsl"/>
    <xsl:import href="https://raw.githubusercontent.com/Nictiz/HL7-mappings/MP920/ada_2_fhir-r4/fhir/2_fhir_fixtures.xsl"/>
    <xsl:output indent="yes" omit-xml-declaration="yes"/>

    <xsl:strip-space elements="*"/>

    <xsl:param name="transactionType"/>
    <xsl:param name="inputDir"/>
    <xsl:param name="outputDir"/>

    <xsl:variable name="transactionTypeNormalized" select="normalize-space(lower-case($transactionType))"/>
    <xsl:variable name="inputDirNormalized" select="nf:normalize-path($inputDir)"/>
    <xsl:variable name="outputDirNormalized" select="nf:normalize-path($outputDir)"/>

    <xsl:variable name="bsnSystem" select="$oidMap[@oid = $oidBurgerservicenummer]/@uri"/>

    <xd:doc>
        <xd:desc>Start template. Handles some ada transactions, converts them to nts. Very specific for each transaction.</xd:desc>
    </xd:doc>
    <xsl:template match="/">
        <xsl:call-template name="util:logMessage">
            <xsl:with-param name="level" select="$logINFO"/>
            <xsl:with-param name="msg">transactionType: <xsl:value-of select="$transactionTypeNormalized"/> - inputDir: <xsl:value-of select="$inputDirNormalized"/> - outputDir: <xsl:value-of select="$outputDirNormalized"/></xsl:with-param>
        </xsl:call-template>

        <!-- ada files have been prepocessed per building block and scenarioset -->
        <xsl:for-each select="collection(concat($inputDirNormalized, '?select=mg-mp-mg-tst-*.xml'))">
            <xsl:variable name="buildingBlockShort" select="substring-before(substring-after(./adaxml/data/beschikbaarstellen_medicatiegegevens/@id, 'mg-mp-mg-tst-'), '-Scenarioset')"/>
            <xsl:variable name="scenarioset" select="xs:integer(replace(./adaxml/data/beschikbaarstellen_medicatiegegevens/scenario-nr/@value, '(\d+)\.?(\d*[a-z]?)\*?\s?.*', '$1'))"/>
            <xsl:choose>
                <!-- Do nothing for scenarioset 0, handled by manually maintaining nts due to complexities in generating this -->
                <xsl:when test="$scenarioset = 0"/>
                <xsl:otherwise>
                    <xsl:call-template name="createNts">
                        <xsl:with-param name="buildingBlockShort" select="$buildingBlockShort"/>
                        <xsl:with-param name="scenarioset" select="$scenarioset"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <xd:doc>
        <xd:desc>Creates NTS</xd:desc>
        <xd:param name="buildingBlockShort">The building block abbreviation, such as MA, MGB and the like</xd:param>
        <xd:param name="scenarioset">The scenarioset to be converted into nts format</xd:param>
    </xd:doc>
    <xsl:template name="createNts">
        <xsl:param name="buildingBlockShort"/>
        <xsl:param name="scenarioset"/>

        <xsl:variable name="adaInstance" select="adaxml/data/beschikbaarstellen_medicatiegegevens"/>

        <xsl:variable name="buildingBlockLong">
            <xsl:choose>
                <xsl:when test="$buildingBlockShort = 'MA'">MedicationAgreement</xsl:when>
                <xsl:when test="$buildingBlockShort = 'MGB'">MedicationUse</xsl:when>
                <xsl:when test="$buildingBlockShort = 'TA'">AdministrationAgreement</xsl:when>
                <xsl:when test="$buildingBlockShort = 'VV'">DispenseRequest</xsl:when>
                <xsl:when test="$buildingBlockShort = 'MTD'">MedicationAdministration</xsl:when>
                <xsl:when test="$buildingBlockShort = 'MVE'">MedicationDispense</xsl:when>
                <xsl:when test="$buildingBlockShort = 'WDS'">VariableDosingRegimen</xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="util:logMessage">
                        <xsl:with-param name="level" select="$logFATAL"/>
                        <xsl:with-param name="msg">Could not determine building block: <xsl:value-of select="$buildingBlockShort"/></xsl:with-param>
                        <xsl:with-param name="terminate" select="true()"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="scenario">x</xsl:variable>
        <xsl:variable name="newFilename" select="concat('mp9-', lower-case($buildingBlockShort), '-', $transactionTypeNormalized, '-', $scenarioset, '-', $scenario, '.xml')"/>
        <xsl:call-template name="util:logMessage">
            <xsl:with-param name="level" select="$logINFO"/>
            <xsl:with-param name="msg">processing <xsl:value-of select="$newFilename"/></xsl:with-param>
        </xsl:call-template>

        <xsl:variable name="ntsScenario" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$transactionTypeNormalized = ('retrieve', 'send')">client</xsl:when>
                <xsl:when test="$transactionTypeNormalized = ('serve', 'receive')">server</xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">Unknown transactionType</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="matchCategoryCode">
            <xsl:choose>
                <xsl:when test="$buildingBlockShort = 'TA'">
                    <xsl:value-of select="$taCode"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'VV'">
                    <xsl:value-of select="$vvCode"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MTD'">
                    <xsl:value-of select="$mtdCode"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MA'">
                    <xsl:value-of select="$maCodeMP920"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MVE'">
                    <xsl:value-of select="$mveCode"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MGB'">
                    <xsl:value-of select="$mgbCode"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'WDS'">
                    <xsl:value-of select="$wdsCode"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="matchResource">
            <xsl:choose>
                <xsl:when test="$buildingBlockShort = ('TA', 'MVE')">
                    <xsl:value-of select="'MedicationDispense'"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = ('VV', 'MA', 'WDS')">
                    <xsl:value-of select="'MedicationRequest'"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MGB'">
                    <xsl:value-of select="'MedicationStatement'"/>
                </xsl:when>
                <xsl:when test="$buildingBlockShort = 'MTD'">
                    <xsl:value-of select="'MedicationAdministration'"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="patientBsn" select="$adaInstance[1]/patient/identificatienummer/@value"/>

        <!-- AWE: don't like this, too much repetition, the query params are the same per building block except for BSN and scenario 0 -->
        <xsl:variable name="additionalScenarioParams" select="document('queryDescription.xml')/Output/*[local-name() = nf:first-cap($transactionTypeNormalized)]/TestScript[@fileName = $newFilename]/@params"/>
        <xsl:variable name="theScenarioParams">
            <xsl:choose>
                <xsl:when test="string-length($additionalScenarioParams) gt 0">
                    <xsl:value-of select="$additionalScenarioParams"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('?patient.identifier=', $bsnSystem, '|', $patientBsn, '&amp;category=http://snomed.info/sct|', $matchCategoryCode, '&amp;_include=', $matchResource, ':medication')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="returnCount" select="count($adaInstance/medicamenteuze_behandeling/*[not(self::identificatie)])"/>
        <xsl:variable name="returnMedicationCount" select="count($adaInstance/bouwstenen/farmaceutisch_product)"/>
        <xsl:variable name="returnEntryCount" select="$returnCount + $returnMedicationCount"/>
        <xsl:variable name="returnEntryBreakdown">
            <xsl:choose>
                <xsl:when test="$returnEntryCount gt 0">
                    <xsl:value-of select="concat('(Consists of ', $returnCount, ' ', $matchResource, ' and ', $returnMedicationCount, ' Medication resources.)')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>(Consists of no resources.)</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="description" as="xs:string?">
            <xsl:choose>
                <xsl:when test="string-length($adaInstance/@title) gt 0 and string-length($adaInstance/@desc) gt 0">
                    <xsl:value-of select="string-join($adaInstance/@title | $adaInstance/@desc, ' - ')"/>
                </xsl:when>
                <xsl:when test="string-length($adaInstance/@title) gt 0">
                    <xsl:value-of select="$adaInstance/@title"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$adaInstance/@desc"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:call-template name="util:logMessage">
            <xsl:with-param name="level" select="$logINFO"/>
            <xsl:with-param name="msg">outputting <xsl:value-of select="$newFilename"/></xsl:with-param>
        </xsl:call-template>
        <xsl:result-document href="{concat($outputDirNormalized,nf:first-cap($transactionTypeNormalized),'/',$buildingBlockLong,'/',$newFilename)}">
            <TestScript xmlns="http://hl7.org/fhir" xmlns:nts="http://nictiz.nl/xsl/testscript" nts:scenario="{$ntsScenario}">
                <xsl:choose>
                    <xsl:when test="$transactionTypeNormalized = 'retrieve'">
                        <id value="mp9-{$buildingBlockLong}-retrieve-{$scenarioset}-{$scenario}"/>
                        <version value="r4-mp9-2.0.0"/>
                        <name value="Medication Process 9 2.0.0  - {$buildingBlockLong} - Retrieve - Scenario {$scenarioset}.{$scenario}"/>
                        <description value="Scenario {$scenarioset}.{$scenario} - {$description}"/>
                        <nts:includeDateT value="no"/>
                        
                        <test id="Scenario-{$scenarioset}-{$scenario}">
                            <name value="Scenario {$scenarioset}.{$scenario}"/>
                            <description value="{$description}"/>
                            <nts:include value="operation-search">
                                <nts:with-parameter name="description" value="Query {$matchResource} resource(s) for {$buildingBlockLong}"/>
                                <nts:with-parameter name="resource" value="{$matchResource}"/>
                                <nts:with-parameter name="params" value="{$theScenarioParams}"/>
                            </nts:include>
                            <nts:include value="canary-assert.response.successfulSearch" scope="common"/>
                            <nts:include value="assert-returnCount" scope="project">
                                <nts:with-parameter name="resource" value="{$matchResource}"/>
                                <nts:with-parameter name="count" value="{$returnCount}"/>
                            </nts:include>
                            <nts:include value="assert-returnEntryCountAtLeast" scope="project">
                                <nts:with-parameter name="count" value="{$returnEntryCount}"/>
                                <nts:with-parameter name="breakdown" value="{$returnEntryBreakdown}"/>
                            </nts:include>
                        </test>
                    </xsl:when>
                    <xsl:when test="$transactionTypeNormalized = 'serve'">
                        <id value="mp9-{$buildingBlockLong}-serve-{$scenarioset}-{$scenario}"/>
                        <version value="r4-mp9-2.0.0"/>
                        <name value="Medication Process 9 2.0.0  - MedicationAgreement (NL: MedicatieAfspraak) - Serve - Scenario {$scenarioset}.{$scenario}"/>
                        <description value="Scenario {$scenarioset}.{$scenario} - {$description}"/>
                        <nts:includeDateT value="no"/>
                        
                        <test id="Scenario-{$scenarioset}-{$scenario}">
                            <name value="Scenario {$scenarioset}.{$scenario}"/>
                            <description value="{$description}"/>
                            <nts:include value="operation-search">
                                <nts:with-parameter name="description" value="Test server to serve {$matchResource} resource(s) for {$buildingBlockLong}"/>
                                <nts:with-parameter name="resource" value="{$matchResource}"/>
                                <nts:with-parameter name="params" value="{$theScenarioParams}"/>
                            </nts:include>
                            <nts:include value="assert.response.successfulSearch" scope="common"/>
                            <nts:include value="mp9-validation"/>
                            <nts:include value="assert-responseBundleContent-noMM"/>
                            <nts:include value="assert-returnCountAtLeast" scope="project">
                                <nts:with-parameter name="resource" value="{$matchResource}"/>
                                <nts:with-parameter name="count" value="{$returnCount}"/>
                            </nts:include>
                            <nts:include value="assert-returnEntryCountAtLeast" scope="project">
                                <nts:with-parameter name="count" value="{$returnEntryCount}"/>
                                <nts:with-parameter name="breakdown" value="{$returnEntryBreakdown}"/>
                            </nts:include>
                        </test>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="util:logMessage">
                            <xsl:with-param name="level" select="$logFATAL"/>
                            <xsl:with-param name="msg">Different xslt should be called for transactionType: <xsl:value-of select="$transactionTypeNormalized"/></xsl:with-param>
                            <xsl:with-param name="terminate" select="true()"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </TestScript>
        </xsl:result-document>

    </xsl:template>

    <xd:doc>
        <xd:desc>Capitalize first letter of a string</xd:desc>
        <xd:param name="in">The string to be handled</xd:param>
    </xd:doc>
    <xsl:function name="nf:first-cap" as="xs:string?">
        <xsl:param name="in" as="xs:string?"/>
        <xsl:sequence select="concat(upper-case(substring($in, 1, 1)), substring($in, 2))"/>
    </xsl:function>

    <xd:doc>
        <xd:desc>Normalize a filepath</xd:desc>
        <xd:param name="in">The string to be handled</xd:param>
    </xd:doc>
    <xsl:function name="nf:normalize-path" as="xs:string?">
        <xsl:param name="in" as="xs:string?"/>
        <xsl:variable name="fixSlashes" select="replace($in, '\\', '/')"/>
        <xsl:variable name="filePrefix">
            <xsl:choose>
                <xsl:when test="starts-with($fixSlashes, 'file:/')">
                    <xsl:value-of select="$fixSlashes"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('file:/', $fixSlashes)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="trailingSlash">
            <xsl:choose>
                <xsl:when test="ends-with($filePrefix, '/')">
                    <xsl:value-of select="$filePrefix"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($filePrefix, '/')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="$trailingSlash"/>
    </xsl:function>

    <xsl:function name="nf:compare-strings" as="xs:string?">
        <xsl:param name="in1" as="xs:string?"/>
        <xsl:param name="in2" as="xs:string?"/>
        <xsl:param name="i" as="xs:integer"/>

        <xsl:choose>
            <xsl:when test="$i gt string-length($in1)">
                <xsl:value-of select="$in1"/>
            </xsl:when>
            <xsl:when test="substring($in1, $i, 1) = substring($in2, $i, 1)">
                <xsl:value-of select="nf:compare-strings($in1, $in2, $i + 1)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="substring($in1, 1, $i - 1)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
