
/*                                                                                            */
/* bootstrap-rows.sql                                                                         */
/*                                                                                            */
/* Inserts a row into each of the central tracking/data provenance tables.                    */
/*                                                                                            */
/* This file was generated automatically by dumpSchema.pl on Wed Feb 12 12:22:24 EST 2003     */
/*                                                                                            */

SET ECHO ON
SPOOL bootstrap-rows.log

INSERT INTO Coretest.UserInfo VALUES(UserInfo_sq.nextval, 'dba', 'dba', 'Database', 'Administrator', 'unknown', NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

INSERT INTO Coretest.ProjectInfo VALUES(ProjectInfo_sq.nextval, 'Database administration', NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

INSERT INTO Coretest.GroupInfo VALUES(GroupInfo_sq.nextval, 'dba', NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

INSERT INTO Coretest.Algorithm VALUES(Algorithm_sq.nextval, 'SQL*PLUS', NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

INSERT INTO Coretest.AlgorithmImplementation VALUES(AlgorithmImplementation_sq.nextval, 1, 'unknown', NULL, NULL, NULL, NULL, NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

INSERT INTO Coretest.AlgorithmInvocation VALUES(AlgorithmInvocation_sq.nextval, 1, SYSDATE, SYSDATE, NULL, NULL, NULL, 'Row(s) inserted', NULL, SYSDATE, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1);

COMMIT;

/* 6 rows */

SPOOL OFF
SET ECHO OFF
DISCONNECT
EXIT
