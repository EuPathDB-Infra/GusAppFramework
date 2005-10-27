package org.gusdb.dbadmin.model;

/**
 * @author msaffitz
 * @version $Revision$ $Date: 2005-06-16 16:35:04 -0400 (Thu, 16 Jun
 *          2005) $
 */
public class Sequence extends DatabaseObject {

    private int      start;
    private GusTable table;

    public GusTable getTable( ) {
        return table;
    }

    public void setTable( GusTable table ) {
        if ( this.table != table ) {
            this.table = table;
            this.table.setSequence( this );
        }
    }

    public int getStart( ) {
        return start;
    }

    public void setStart( int start ) {
        this.start = start;
    }

    public boolean equals( DatabaseObject o ) {
        Sequence other = (Sequence) o;

        if ( start != other.getStart( ) ) return false;
        return super.equals( o );
    }

}
