package org.gusdb.objrelj;

import java.rmi.Remote;
import java.rmi.RemoteException;

import java.util.Vector;

/**
 * RemoteDatabaseConnectionI.java
 *
 * This interface is identical to <code>DatabaseConnectionI</code>, except that 
 * it is tagged as a remote interface.
 *
 * @author Dave Barkan, Jonathan Crabtree
 * @version $Revision$ $Date$ $Author$
 */
public interface RemoteDatabaseConnectionI extends DatabaseConnectionI, Remote {
} // RemoteDatabaseConnectionI
