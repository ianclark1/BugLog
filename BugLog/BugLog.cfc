<cfcomponent hint="Passes Exceptions and Bug Reports to BugLog" extends="coldbox.system.Plugin" output="false" cache="true" cachetimeout="0">
	<cffunction name="init" access="public" returntype="BugLog" output="false">
		<cfargument name="controller" type="any" required="true">
		<cfscript>
			super.Init(arguments.controller);
			setPluginName("BugLog");
			setPluginVersion("1.2");
			setPluginDescription("A Coldbox plugin to log errors using BugLog.");			
			setPluginAuthor("Donaldo DE SOUSA");
			setPluginAuthorURL("http://twitter.com/I_TwitIT");
			
			instance = StructNew();
			instance.isListenerActive = false;
			instance.apikey = "";
			instance.escapePattern = createObject('java','java.util.regex.Pattern').compile("[^\u0009\u000a\u000d\u0020-\ud7ff\ud800\udc00\ue000-\ufffd\u100000-\u10ffff]");			
			instance.hostName = getPlugin('JVMUtils').getInetHost();
			instance.bugEmailRecipients = getSetting("bugEmailRecipients",false);
			
			initWebService();
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="initWebService" returntype="boolean" access="private" output="false">
		<cftry>
			<cfscript>
				if ( !instance.isListenerActive ) {
					// Instantiate reference to listener
					try {
						instance.oBugLogWS = getPlugin('Webservices').getWSobj('BugLog');
						instance.isListenerActive = true;
					} catch(any e) {
						if ( Len(instance.bugEmailRecipients) ) {
							sendEmail(instance.bugEmailRecipients,e.detail,e.message);
						}
						instance.isListenerActive = false;
					}
				}
			</cfscript>				
			<cfcatch type="any">
				<cfset instance.isListenerActive = false>				
			</cfcatch>
		</cftry>
		<cfreturn instance.isListenerActive>
	</cffunction>
   
	<!--- creates and logs bug report --->
	<cffunction name="logError" access="public" output="false" returntype="boolean">
		<cfargument name="oExceptionBean" required="true" type="any" />
		<cfargument name="sSseverityCode" type="string" default="error" />

		<cfscript>
			var tmpCFID = "";
			var tmpCFTOKEN = "";
			var tagContext = oExceptionBean.getTagContext();
			var tplLine = "";
			if ( ArrayLen(tagContext) >= 1 ) {
				tplLine = tagContext[1].template & ":" & tagContext[1].line;
			} else {
				tplLine = cgi.SCRIPT_NAME & ":0";
			}
		</cfscript>
		<cfsavecontent variable="longMessage">
			<cfoutput>
<h3>Exception Summary</h3>
<table style="font-size:11px;font-family:arial;">
<tr>
	<td><b>Application:</b></td>
	<td>#application.applicationname#</td>
</tr>
<tr>
	<td><b>Host:</b></td>
	<td>#instance.hostName#</td>
</tr>
<tr>
	<td><b>Server Date/Time:</b></td>
	<td>#lsDateFormat(now())# #lsTimeFormat(now())#</td>
</tr>
<tr>
	<td><b>Type:</b></td>
	<td>#oExceptionBean.getType()#</td>
</tr>
<tr>
	<td><b>Detail:</b></td>
	<td>#oExceptionBean.getDetail()#</td>
</tr>
<tr>
	<td><b>Script Name (CGI):</b></td>
	<td>#cgi.SCRIPT_NAME#</td>
</tr>
<tr>
	<td><b>User Agent:</b></td>
	<td>#cgi.HTTP_USER_AGENT#</td>
</tr>
<tr>
	<td><b>URI:</b></td>
	<td>#CreateObject("java", "coldfusion.filter.FusionContext").getCurrent().getRequest().getHeader("REQUEST-URI")#</td>
</tr>
<tr>
	<td><b>IP Client</b></td>
	<td></cfoutput>
			<cfscript>
				if ( Len(CGI.HTTP_X_Forwarded_For) != 0 ) {
					WriteOutput(CGI.HTTP_X_Forwarded_For);
				} else if ( Len(CGI.HTTP_CLIENT_IP) != 0 ) {
					WriteOutput(CGI.HTTP_CLIENT_IP);
				} else {
					WriteOutput(CGI.REMOTE_ADDR);
				}
			</cfscript>
	<cfoutput></td>
</tr>
<tr valign="top">
	<td><strong>Coldfusion ID:</strong></td>
	<td>
						<cftry>
		[SESSION] &nbsp;&nbsp;&nbsp;&nbsp;
		CFID = #session.cfid#;
		CFTOKEN = #session.cftoken#
		JSessionID=#session.sessionID#
							<cfcatch type="any">
		<span style="color:red;">#cfcatch.message#</span>	
							</cfcatch>
						</cftry><br>
						<cftry>
		[CLIENT] &nbsp;&nbsp;&nbsp;&nbsp;
		CFID = #client.cfid#;
		CFTOKEN = #client.cftoken#
							<cfcatch type="any">
		<span style="color:red;">#cfcatch.message#</span>	
							</cfcatch>
						</cftry><br>
						<cftry>
		[COOKIES] &nbsp;&nbsp;&nbsp;&nbsp;
		CFID = #cookie.cfid#;
		CFTOKEN = #cookie.cftoken#
							<cfcatch type="any">
		<span style="color:red;">#cfcatch.message#</span>	
							</cfcatch>
						</cftry><br>
	</td>
</tr>					
</table>
<h3>Exception Info</h3>
TagContext&nbsp;:<br />
			<cfdump var="#tagContext#"><br />
LockOperation&nbsp;:<br />
			<cfdump var="#oExceptionBean.getLockOperation()#"><br />
NativeErrorCode&nbsp;:<br />
			<cfdump var="#oExceptionBean.getNativeErrorCode()#"><br />
Sql&nbsp;:<br />
			<cfdump var="#oExceptionBean.getSql()#"><br />
Param&egrave;tres&nbsp;:<br />
			<cfdump var="#oExceptionBean.getWhere()#"><br />
			
<h3>Additional Info</h3>
QueryString&nbsp;:
			<cfdump var="#URL#">
Form&nbsp;:
			<cfdump var="#Form#">
Client&nbsp;:
			<cfdump var="#Client#">
Cookie&nbsp;:
			<cfdump var="#Cookie#">
			</cfoutput>
		</cfsavecontent>
		<cfscript>
			// check if there are valid CFID/CFTOKEN values available
			if ( isDefined("cfid") ) {
				tmpCFID = cfid;
			}
			if ( isDefined("cftoken") ) {
				tmpCFTOKEN = cftoken;
			}
		</cfscript>
		<!--- submit error --->
		<cftry>
			<!--- send bug via a webservice (SOAP) --->
			<cfset instance.oBugLogWS.logEntry(
				dateTime 			= Now(), 
				message 			= sanitizeForXML(oExceptionBean.getMessage()), 
				applicationCode 	= application.applicationname, 
				severityCode 		= arguments.sSseverityCode,
				hostName 			= instance.hostName,
				exceptionMessage 	= sanitizeForXML(arguments.oExceptionBean.getMessage()),
				exceptionDetails 	= sanitizeForXML(arguments.oExceptionBean.getDetail()),
				CFID 				= tmpCFID,
				CFTOKEN 			= tmpCFTOKEN,
				userAgent 			= cgi.HTTP_USER_AGENT,
				templatePath 		= cgi.SCRIPT_NAME,
				HTMLReport 			= sanitizeForXML(longMessage),
				APIKey 				= instance.apikey,
				TplLine				= tplLine
			)>
			<cfcatch type="any">
				<!--- an error ocurred, if there is an email address stored, then send details to that email, otherwise rethrow --->
				<cfif instance.bugEmailRecipients neq "">
					<cfset instance.isListenerActive = False>
					<cfset sendEmail(oExceptionBean.getMessage(), longMessage, cfcatch.message & cfcatch.detail)>			
				<cfelse>
					<cfrethrow> 
				</cfif>
				<cfset initWebService()>
			</cfcatch>		
		</cftry>
		
		<cfreturn true>
	</cffunction>
	
	<cffunction name="sendEmail" access="private" hint="Sends the actual email message" returntype="void">
		<cfargument name="message" type="string" required="true">
		<cfargument name="longMessage" type="string" required="true">
		<cfargument name="otherError" type="string" required="true">

		<cfmail to="#instance.bugEmailRecipients#" 
				from="exploit.web@argusauto.com" 
				subject="BUG REPORT: [#application.applicationname#] [#instance.hostName#] #arguments.message#" 
				type="html">
			<div style="margin:5px;border:1px solid silver;background-color:##ebebeb;font-family:arial;font-size:12px;padding:5px;">
				This email is sent because the buglog server could not be contacted. The error was:
				#arguments.otherError#
			</div>
			#arguments.longMessage#
		</cfmail>		
	</cffunction>
	
	<cffunction name="sanitizeForXML" access="private" returnType="string" hint="sanitizes a string to make it safe for xml">
		<cfargument name="inString" type="string" required="true" />
		<cfscript>
			var matcher = instance.escapePattern.matcher(inString);
			var buffer = createObject('java','java.lang.StringBuffer').init('');
			while ( matcher.find() ) {
				matcher.appendReplacement(buffer,"");
			}
			matcher.appendTail(buffer);
			return buffer.toString();
		</cfscript>
	</cffunction>
</cfcomponent>