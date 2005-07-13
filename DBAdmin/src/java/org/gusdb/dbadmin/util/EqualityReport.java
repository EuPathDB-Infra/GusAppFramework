/**
 * $Id:$
 */
package org.gusdb.dbadmin.util;

import java.io.IOException;
import java.io.Writer;
import java.util.Collection;
import java.util.Iterator;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.gusdb.dbadmin.model.Database;
import org.gusdb.dbadmin.model.Table;

/**
 * @author msaffitz
 */
public class EqualityReport {

    private Log      log = LogFactory.getLog( EqualityReport.class );
    private Database leftDatabase;
    private Database rightDatabase;
    
    private SchemaComparator comparator;

    public EqualityReport( Database left, Database right ) {
        this.leftDatabase = left;
        this.rightDatabase = right;
        comparator = new SchemaComparator(left, right);
    }

    public void writeReport( Writer writer ) throws IOException {
        writer.write( "===============================================================\n" );
        writer.write( "== GUS Schema Comparison Report                              ==\n" );
        writer.write( "==                                                           ==\n" );
        writer.write( "== Left Database: " + leftDatabase.getName( ) + "             ==\n" );
        writer.write( "== Right Database: " + rightDatabase.getName( ) + "           ==\n" );
        writer.write( "===============================================================\n\n" );
        writeRenamedReport( writer );
        writeDroppedReport( writer );
        writeChangedReport( writer );
        writeUnchangedReport( writer);
        writer.flush( );
    }

    private void writeRenamedReport( Writer writer ) throws IOException {

        writer.write( " == Renamed Tables ==\n\n" );
        for ( Iterator i = comparator.findLeftRenamedTables().keySet().iterator(); i.hasNext(); ) {
            Table table = (Table) i.next();
            writer.write( table.getSchema().getName() + "." + table.getName() + " renamed to ");
            Collection newTables = comparator.findRenameMatches(table, 0);
            if ( newTables.isEmpty() ) {
               writer.write( "ERROR:  No Table\n");
            }
            else if ( newTables.size() == 1 ) {
                Table newTable = (Table) newTables.toArray()[0];
                writer.write( newTable.getSchema().getName() + "." + newTable.getName() + "\n");
            } 
            else {
                writer.write("\n\t");
                for ( Iterator j = newTables.iterator(); j.hasNext(); ) {
                    Table newTable = (Table) j.next();
                    writer.write( " " + newTable.getSchema().getName() + "." + newTable.getName() );
                }
                writer.write("\n");
            }
        }
        writer.write("\n");
        writer.flush();
        
        
    }
    
    private void writeUnchangedReport(Writer writer ) throws IOException {
        writer.write( " == Unchanged Tables == \n\n" );
        
        for ( Iterator i = comparator.findLeftIdenticalTables().iterator(); i.hasNext(); ) {
            Table table = (Table) i.next();
            writer.write( table.getSchema().getName() + "." + table.getName() + " present in both schemas \n");
        }
        writer.write("\n");
        writer.flush();
    }

    private void writeDroppedReport(Writer writer) throws IOException {
        writer.write( " == Dropped Tables == \n\n" );
        for ( Iterator i = comparator.findLeftDroppedTables().iterator(); i.hasNext(); ) {
            Table table = (Table) i.next();
            writer.write( table.getSchema().getName() + "." + table.getName() + " not present in right schema \n");
        }
        writer.write("\n");
        writer.flush();
    }
    
    private void writeChangedReport(Writer writer) throws IOException {
        writer.write( " == Changed Tables == \n\n");
        for ( Iterator i = comparator.findLeftChangedTables().keySet().iterator(); i.hasNext(); ) {
            Table table = (Table) i.next();
            writer.write( table.getSchema().getName() + "." + table.getName() + " has changed:  \n");
            for ( Iterator j = ((Collection) comparator.findLeftChangedTables().get(table)).iterator(); j.hasNext(); ) {
                writer.write ( "\t" + (String) j.next() + "\n");
            }
        }
        
        writer.write("\n");
        writer.flush();
    }
    
}
