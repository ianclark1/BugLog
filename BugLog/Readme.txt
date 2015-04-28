
******************************	GETTING BUGLOG SERVER			******************************
// Download and install buglog application from http://bugloghq.riaforge.org/
// I recommend installing it in an separated server.
// More informations at http://www.oscararevalo.com/index.cfm/BugLogHQ


******************************	SETTING UP YOUR CONFIG/COLDBOX.CFC	******************************

// Add the following code to declare your exception handler
// I named my handler Main.cfc so replace "Main" by you exception handler filename (without the .cfc extention)

coldbox = {
	exceptionHandler = "Main.onException",
	onInvalidEvent	= "Main.onPageNotFound"
}

// Add the following code to declare the buglog webservice 
// replace "yourBuglogServerHost" with the hostname or IP adresse of your buglog server
webservices = {
	BugLog	= "http://yourBuglogServerHost/bugLog/listeners/bugLogListenerWS.cfc?wsdl"
}

// Add the following code to declare the buglog email recipient
// replace "yourEMailAdresse" with your email
// you can define multiple emails separated by comma
settings = {
	bugEmailRecipients = "yourEMailAdresse"
}

****************************** 	SETTING UP YOUR EXCEPTION HANDLER	******************************

// Add the following code to handlers\YourExceptionHandler.cfc where "YourExceptionHandler.cfc" is your exception handler filename
<cffunction name="onException" access="public" output="false" returntype="void">
	<cfargument name="event" type="any">	

	<cfscript>
	//Grab the Exception From the request collection
	var oExceptionBean = event.getValue("ExceptionBean");

	getPlugin(plugin="BugLog",customPlugin=true).logError(oExceptionBean);
	</cfscript>
	
</cffunction>

// replace "YourWebsiteURL" by the URL of your website 
<cffunction name="onPageNotFound" access="public" output="false" returntype="void" >
	<cfargument name="event" type="any">
	<cfscript>
	var rc = event.getCollection();
	var url = "http://YourWebsiteURL"	
	var controller = application.cbController;
	var exceptionService = controller.getExceptionService();
	var ExceptionBean = "";

	try {
		$throw(message="The request '#CGI.SCRIPT_NAME#' is invalid",detail="This error is generated when the request doesn't match a valid event",type="404");
	} catch (any e){
		ExceptionBean = exceptionService.ExceptionHandler(e,e.type,e.message);	
		getPlugin("BugLog",true).logError(ExceptionBean,"info");
	}
	</cfscript>
	<cflocation url="#url#" addtoken="false" statusCode="300">
</cffunction>

******************************	ADDING THE PLUGIN			******************************

Just drop the BugLog.cfc file into your application plugins directory (/plugins/) 