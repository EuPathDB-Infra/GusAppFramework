<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>

<%@ attribute name="title"
              description="Value to appear in page's title"
%>
<%@ attribute name="banner"
              required="true"
              description="Value to appear at top of page"
%>
<html>
<head>
<title>
<c:out value="${title}" default="${banner}" />
</title>
<link rel="StyleSheet" href="/sampleWDK/style.css" type="text/css">
</head>
<body>
<table width="100%"><tr>
<td><a href="/sampleWDK/"><img src="/sampleWDK/images/WDKTestSite.png" border="0" alt="Site logo"></a></td>
<td><h1>${banner}</h1></td></tr></table>
<hr>
