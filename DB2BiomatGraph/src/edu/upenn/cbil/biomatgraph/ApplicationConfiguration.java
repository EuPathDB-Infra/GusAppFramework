package edu.upenn.cbil.biomatgraph;

import java.io.IOException;
import java.util.Properties;

import org.apache.log4j.PropertyConfigurator;

public class ApplicationConfiguration {
  public static String databaseUser;
  public static String databasePassword;
  public static String databaseHost;
  public static String databaseSid;
  public static String databasePoolMinSize;
  public static String databasePoolMaxSize;
  public static String filePrefix;
  public static String graphvizDotPath;
  public static final String MATERIAL_ENTITY = "material entity";
  public static final String DATA_ITEM = "data item";
  public static final String MAP_FILE_NAME = "map";

		
  public void applicationSetup() throws ApplicationException {
    try {
      Properties properties = new Properties();
      properties.load(ClassLoader.getSystemResourceAsStream("application.properties"));
      databaseUser = (String)properties.get("database.user");
      databasePassword = (String)properties.get("database.password");
      databaseHost = (String)properties.get("database.host");
      databaseSid = (String)properties.get("database.sid");
      databasePoolMinSize = (String)properties.get("database.poolMinSize");
      databasePoolMaxSize = (String)properties.get("database.poolMaxSize");
      filePrefix = (String)properties.get("file.prefix");
      graphvizDotPath = (String)properties.get("graphviz.dot");
      log4jSetup();
    }
    catch(IOException ioe) {
	  throw new ApplicationException(ioe.getMessage());
	}
  }
	
  public void log4jSetup() throws ApplicationException, IOException {
    Properties properties = new Properties();
	properties.load(ClassLoader.getSystemResourceAsStream("log4j.properties"));
	PropertyConfigurator.configure(properties);
  }
}

