<%@ WebHandler Language="C#" Class="RequestLeadTimeControlHandler" %>

using System;
using System.IO;
using System.Xml;
using System.Net;
using System.Web;
using MarvalSoftware.UI.WebUI.ServiceDesk.RFP.Plugins;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Xml.Serialization;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using MarvalSoftware;

/// <summary>
/// Reques tLead Time Control Plugin Handler
/// </summary>
public class RequestLeadTimeControlHandler : PluginHandler
{
    public override bool IsReusable { get { return false; } }

    private string mSMBaseUrl { get { return string.Format("{0}://{1}{2}{3}", HttpContext.Current.Request.Url.Scheme, HttpContext.Current.Request.Url.Host, HttpContext.Current.Request.Url.Port == 80 || HttpContext.Current.Request.Url.Port == 443 ? "" : string.Format(":{0}", HttpContext.Current.Request.Url.Port), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath); } }
    private string pluginActionMessageKey { get { return this.GlobalSettings["Plugin Rules Action Message"]; } }
    private string mSMWSEAdr { get { return this.GlobalSettings["MSM WSE Address"]; } }
    private string mSMWSEEncUsr { get { return this.GlobalSettings["MSM WSE User Name"]; } }
    private string mSMWSEEncPwd { get { return this.GlobalSettings["MSM WSE Password"]; } }
    private int tmpInt = 0;

    /// <summary>
    /// Main Request Handler
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        if (context.Request.HttpMethod == "GET")
        {
            string actionMessageKey = context.Request.Params["ActionMessageKey"] ?? string.Empty;
            if (string.IsNullOrWhiteSpace(actionMessageKey)) context.Response.Write(JsonHelper.ToJSON(pluginActionMessageKey));
            else context.Response.Write(JsonHelper.ToJSON(getPluginRulesContent(actionMessageKey)));
        }
    }

    /// <summary>
    /// Return Action Message Content
    /// </summary>
    private string getPluginRulesContent(string msgKeys)
    {
        jsonRulesObject pluginRules = new jsonRulesObject();
        List<Rule> pluginRulesList = new List<Rule>();
        if (string.IsNullOrEmpty(msgKeys)) return string.Empty;
        try
        {
            Dictionary<int, string> messageContents = getActionMessageContents(msgKeys);
            foreach (var messageContent in messageContents)
            {
                if (!string.IsNullOrEmpty(messageContent.Value))
                {
                    jsonRulesObject pluginRulesTmp = JsonHelper.DeserializeJSONObject<jsonRulesObject>(messageContent.Value);
                    if (pluginRulesTmp != null && pluginRulesTmp.rules != null && pluginRulesTmp.rules.Length > 0)
                    {
                        foreach (var pr in pluginRulesTmp.rules)
                        {
                            pluginRulesList.Add(pr);
                        }
                    }
                }
            }
            pluginRules.rules = pluginRulesList.ToArray();
        }
        catch (WebException ex)
        {
            return string.Format("Error parsing plugin rules! {0}", ex.Message);
        }
        return JsonHelper.ToJSON(pluginRules);
    }

    /// <summary>
    /// Return Action Message Contents List when several message keys supplied
    /// </summary>
    private Dictionary<int, string> getActionMessageContents(string msgKeys)
    {
        Dictionary<int, string> messageContents = new Dictionary<int, string>();
        if (string.IsNullOrEmpty(msgKeys)) return messageContents;
        try
        {
            HttpWebRequest request = CreateWebRequest(this.mSMWSEAdr, "http://www.marvalbaltic.lt/MSM/WebServiceExtensions/GetActionMessages", CreateSoapEnvelope(this.mSMWSEEncUsr, this.mSMWSEEncPwd, msgKeys));
            string response = ProcessRequest(request);
            if (!string.IsNullOrEmpty(response))
            {
                XmlDocument soapResponse = new XmlDocument();
                soapResponse.LoadXml(XmlHelper.EscapeEscapeChar(response));
                XmlNodeList nodes = soapResponse.GetElementsByTagName("MSMActionMessage");
                foreach (XmlNode n in nodes)
                {
                    if (int.TryParse(n["ID"].InnerText, out tmpInt)) messageContents.Add(tmpInt, n["Content"].InnerText);
                }
            }
        }
        catch (WebException ex) { /*???*/ }
        return messageContents;
    }

    //Generic Methods

    /// <summary>
    /// Creates web request SOAP envelope
    /// </summary>
    /// <param name="usr">WSE User name</param>
    /// <param name="pwd">WSE Password</param>
    /// <param name="msgId">Message ID</param>
    /// <returns>The XmlDocument ready to be sent</returns>
    private XmlDocument CreateSoapEnvelope(string Usr, string Pwd, string MsgKey)
    {
        if (MsgKey.Length > 1 && MsgKey[0] == '~') MsgKey = string.Format("id={0}", MsgKey.Substring(1));
        else MsgKey = string.Format("name={0}", MsgKey);
        XmlDocument soapEnvelop = new XmlDocument();
        soapEnvelop.LoadXml(string.Format(
@"<soapenv:Envelope xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:web=""http://www.marvalbaltic.lt/MSM/WebServiceExtensions/"">
    <soapenv:Header xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" />
    <soapenv:Body>
    <web:GetActionMessages>
      <web:username>{0}</web:username>
      <web:password>{1}</web:password>
      <web:sessionKey></web:sessionKey>
      <web:extraFilter>{2}</web:extraFilter>
    </web:GetActionMessages>
  </soapenv:Body>
</soapenv:Envelope>"
, Usr, Pwd, MsgKey));
        return soapEnvelop;
    }

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="url">The url for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private HttpWebRequest CreateWebRequest(string url = null, string action = null, XmlDocument soapEnvelopeXml = null)
    {
        try
        {
            HttpWebRequest webRequest = (HttpWebRequest)WebRequest.Create(url);
            webRequest.Headers.Add("SOAPAction", action);
            webRequest.ContentType = "text/xml;charset=UTF-8";
            webRequest.Accept = "text/xml";
            webRequest.Method = "POST";
            using (Stream stream = webRequest.GetRequestStream()) { soapEnvelopeXml.Save(stream); }
            return webRequest;
        }
        catch { }
        return null;
    }

    /// <summary>
    /// Proccess a HttpWebRequest
    /// </summary>
    /// <param name="request">The HttpWebRequest</param>
    /// <returns>Process Response</returns>
    private string ProcessRequest(HttpWebRequest request)
    {
        try
        {
            if (request == null) return string.Empty;
            using (WebResponse response = request.GetResponse())
            {
                using (StreamReader rd = new StreamReader(response.GetResponseStream()))
                {
                    return rd.ReadToEnd();
                }
            }
        }
        catch { }
        return string.Empty;
    }

    private class jsonRulesObject
    {
        public Rule[] rules { get; set; }
    }

    private class Rule
    {
        public string name { get; set; }
        public Condition[] conditions { get; set; }
		public int leadtimedays { get; set; }
    }
    private class Condition
    {
        public string type { get; set; }
        public int id { get; set; }
        public object value { get; set; }
	}
	
}

/// <summary>
/// JsonHelper Functions
/// </summary>
public static class JsonHelper
{
    public static string replaceLBs(string jsonString)
    {
        return Regex.Replace(jsonString, @"\""[^\""]*?[\n\r]+[^\""]*?\""", m => Regex.Replace(m.Value, @"[\n\r]", "\\n"));
    }
    public static string replaceWildcards(string jsonString)
    {
        return jsonString.Replace("\\n", "").Replace("\\\"", "\"");
    }
    public static string ToJSON(object obj)
    {
        return JsonConvert.SerializeObject(obj);
    }
    public static string SerializeJSONObject<T>(this T JsonObjectToSerialize)
    {
        JsonSerializerSettings jsonSettings = new JsonSerializerSettings()
        {
            TypeNameHandling = TypeNameHandling.Objects
        };
        //jsonSettings.TypeNameHandling = TypeNameHandling.Objects;
        //jsonSettings.MetadataPropertyHandling = MetadataPropertyHandling.Default;
        return JsonConvert.SerializeObject(JsonObjectToSerialize);
        //return JsonConvert.SerializeObject(JsonObjectToSerialize, Newtonsoft.Json.Formatting.Indented, jsonSettings);
    }
    public static T DeserializeJSONObject<T>(this string JsonStringToDeserialize)
    {

        JsonSerializerSettings jsonSettings = new JsonSerializerSettings()
        {
            TypeNameHandling = TypeNameHandling.Objects
        };
        //jsonSettings.TypeNameHandling = TypeNameHandling.Objects;
        //jsonSettings.MetadataPropertyHandling = MetadataPropertyHandling.Default;
        JsonSerializer serializer = new JsonSerializer();
        return JsonConvert.DeserializeObject<T>(JsonStringToDeserialize);
        //return JsonConvert.DeserializeObject<T>(JsonStringToDeserialize, jsonSettings);
    }
}


/// <summary>
/// XmlHelper Functions
/// </summary>
public static class XmlHelper
{
    public static string EscapeEscapeChar(string xmlString)
    {
        if (string.IsNullOrEmpty(xmlString)) return xmlString;
        return xmlString.Replace("\\\"", "\"");
    }
    public static string EscapeXML(string nonXmlString)
    {
        if (string.IsNullOrEmpty(nonXmlString)) return nonXmlString;
        return nonXmlString.Replace("'", "&apos;").Replace("\"", "&quot;").Replace(">", "&gt;").Replace("<", "&lt;").Replace("&", "&amp;");
    }
    public static string UnescapeXML(string xmlString)
    {
        if (string.IsNullOrEmpty(xmlString)) return xmlString;
        return xmlString.Replace("&apos;", "'").Replace("&quot;", "\"").Replace("&gt;", ">").Replace("&lt;", "<").Replace("&amp;", "&");
    }
    public static string SerializeXMLObject<T>(this T xmlObjectToSerialize)
    {
        XmlSerializer xmlSerializer = new XmlSerializer(xmlObjectToSerialize.GetType());
        using (StringWriter textWriter = new StringWriter())
        {
            xmlSerializer.Serialize(textWriter, xmlObjectToSerialize);
            return textWriter.ToString();
        }
    }
    public static T DeserializeXMLObject<T>(this string xmlStringToDeserialize)
    {
        XmlSerializer xmlSerializer = new XmlSerializer(typeof(T));
        using (TextReader reader = new StringReader(xmlStringToDeserialize))
        {
            return (T)xmlSerializer.Deserialize(reader);
        }
    }
}
