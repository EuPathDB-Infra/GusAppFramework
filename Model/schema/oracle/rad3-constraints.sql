
/*                                                                                            */
/* rad3-constraints.sql                                                                       */
/*                                                                                            */
/* This file was generated automatically by dumpSchema.pl on Wed Feb 12 12:30:10 EST 2003     */
/*                                                                                            */

SET ECHO ON
SPOOL rad3-constraints.log

/* NON-PRIMARY KEY CONSTRAINTS */

/* ACQUISITION */
alter table RAD3test.ACQUISITION add constraint FK_ACQ_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.ACQUISITION add constraint FK_ACQ_CHANNEL foreign key (CHANNEL_ID) references RAD3test.CHANNEL (CHANNEL_ID);
alter table RAD3test.ACQUISITION add constraint FK_ACQ_PRTCL foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);

/* ACQUISITIONPARAM */
alter table RAD3test.ACQUISITIONPARAM add constraint FK_ACQPARAM_ACQ foreign key (ACQUISITION_ID) references RAD3test.ACQUISITION (ACQUISITION_ID);

/* ANALYSIS */

/* ANALYSISIMPLEMENTATION */
alter table RAD3test.ANALYSISIMPLEMENTATION add constraint FK_ANLIMP_ANL foreign key (ANALYSIS_ID) references RAD3test.ANALYSIS (ANALYSIS_ID);

/* ANALYSISIMPLEMENTATIONPARAM */
alter table RAD3test.ANALYSISIMPLEMENTATIONPARAM add constraint FK_ANLIMPPARAM_ANLIMP foreign key (ANALYSIS_IMPLEMENTATION_ID) references RAD3test.ANALYSISIMPLEMENTATION (ANALYSIS_IMPLEMENTATION_ID);

/* ANALYSISINPUT */
alter table RAD3test.ANALYSISINPUT add constraint FK_ANLINPUT_ANALYSISINV foreign key (ANALYSIS_INVOCATION_ID) references RAD3test.ANALYSISINVOCATION (ANALYSIS_INVOCATION_ID);
alter table RAD3test.ANALYSISINPUT add constraint FK_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);

/* ANALYSISINVOCATION */
alter table RAD3test.ANALYSISINVOCATION add constraint FK_ANLINV_ANLIMP foreign key (ANALYSIS_IMPLEMENTATION_ID) references RAD3test.ANALYSISIMPLEMENTATION (ANALYSIS_IMPLEMENTATION_ID);

/* ANALYSISINVOCATIONPARAM */
alter table RAD3test.ANALYSISINVOCATIONPARAM add constraint FK_ANLPARAM_ANLINV foreign key (ANALYSIS_INVOCATION_ID) references RAD3test.ANALYSISINVOCATION (ANALYSIS_INVOCATION_ID);

/* ANALYSISOUTPUT */
alter table RAD3test.ANALYSISOUTPUT add constraint FK_ANALYSISOUTPUT4 foreign key (ANALYSIS_INVOCATION_ID) references RAD3test.ANALYSISINVOCATION (ANALYSIS_INVOCATION_ID);

/* ARRAY */
alter table RAD3test.ARRAY add constraint FK_ARRAY_CONTACT foreign key (MANUFACTURER_ID) references SRestest.CONTACT (CONTACT_ID);
alter table RAD3test.ARRAY add constraint FK_ARRAY_EXTDB foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);
alter table RAD3test.ARRAY add constraint FK_ARRAY_ONTO01 foreign key (PLATFORM_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.ARRAY add constraint FK_ARRAY_ONTO02 foreign key (SUBSTRATE_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.ARRAY add constraint FK_ARRAY_PROTOCOL foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);

/* ARRAYANNOTATION */
alter table RAD3test.ARRAYANNOTATION add constraint FK_ARRAYANN_ARRAY foreign key (ARRAY_ID) references RAD3test.ARRAY (ARRAY_ID);

/* ASSAY */
alter table RAD3test.ASSAY add constraint FK_ASSAY_ARRAY foreign key (ARRAY_ID) references RAD3test.ARRAY (ARRAY_ID);
alter table RAD3test.ASSAY add constraint FK_ASSAY_CONTACT foreign key (OPERATOR_ID) references SRestest.CONTACT (CONTACT_ID);
alter table RAD3test.ASSAY add constraint FK_ASSAY_PRTCL foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);
alter table RAD3test.ASSAY add constraint FK_EXTERNALDATABASERELEASE foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* ASSAYBIOMATERIAL */
alter table RAD3test.ASSAYBIOMATERIAL add constraint FK_ASSAYBIOMATERIAL15 foreign key (BIO_MATERIAL_ID) references RAD3test.BIOMATERIALIMP (BIO_MATERIAL_ID);
alter table RAD3test.ASSAYBIOMATERIAL add constraint FK_ASSAYBIOSOURCE13 foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);

/* ASSAYLABELEDEXTRACT */
alter table RAD3test.ASSAYLABELEDEXTRACT add constraint FK_ASSAYLAB_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.ASSAYLABELEDEXTRACT add constraint FK_ASSAYLAB_CHANNEL foreign key (CHANNEL_ID) references RAD3test.CHANNEL (CHANNEL_ID);
alter table RAD3test.ASSAYLABELEDEXTRACT add constraint FK_ASSAYLAB_LEX foreign key (LABELED_EXTRACT_ID) references RAD3test.BIOMATERIALIMP (BIO_MATERIAL_ID);

/* ASSAYPARAM */
alter table RAD3test.ASSAYPARAM add constraint FK_ASSAYPARAM_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.ASSAYPARAM add constraint FK_ASSAYPARAM_PRTOPRM foreign key (PROTOCOL_PARAM_ID) references RAD3test.PROTOCOLPARAM (PROTOCOL_PARAM_ID);

/* BIOMATERIALCHARACTERISTIC */
alter table RAD3test.BIOMATERIALCHARACTERISTIC add constraint FK_BMCHARAC_BIOMAT foreign key (BIO_MATERIAL_ID) references RAD3test.BIOMATERIALIMP (BIO_MATERIAL_ID);
alter table RAD3test.BIOMATERIALCHARACTERISTIC add constraint FK_BMCHARAC_ONTOLOGY foreign key (ONTOLOGY_ENTRY_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);

/* BIOMATERIALIMP */
alter table RAD3test.BIOMATERIALIMP add constraint FK_BIOMATERIALIMP15 foreign key (LABEL_METHOD_ID) references RAD3test.LABELMETHOD (LABEL_METHOD_ID);
alter table RAD3test.BIOMATERIALIMP add constraint FK_BIOMATIMP_TAXON foreign key (TAXON_ID) references SRestest.TAXON (TAXON_ID);
alter table RAD3test.BIOMATERIALIMP add constraint FK_BIOMATTYPE_OE foreign key (BIO_MATERIAL_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.BIOMATERIALIMP add constraint FK_BMI_CONTACT foreign key (BIO_SOURCE_PROVIDER_ID) references SRestest.CONTACT (CONTACT_ID);
alter table RAD3test.BIOMATERIALIMP add constraint FK_BMI_EXTDB foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* BIOMATERIALMEASUREMENT */
alter table RAD3test.BIOMATERIALMEASUREMENT add constraint FK_BMM_BIOMATERIAL foreign key (BIO_MATERIAL_ID) references RAD3test.BIOMATERIALIMP (BIO_MATERIAL_ID);
alter table RAD3test.BIOMATERIALMEASUREMENT add constraint FK_BMM_ONTO foreign key (UNIT_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.BIOMATERIALMEASUREMENT add constraint FK_BMM_TREATMENT foreign key (TREATMENT_ID) references RAD3test.TREATMENT (TREATMENT_ID);

/* CHANNEL */

/* COMPOSITEELEMENTANNOTATION */
alter table RAD3test.COMPOSITEELEMENTANNOTATION add constraint FK_CEANNOT_CE foreign key (COMPOSITE_ELEMENT_ID) references RAD3test.COMPOSITEELEMENTIMP (COMPOSITE_ELEMENT_ID);

/* COMPOSITEELEMENTGUS */
alter table RAD3test.COMPOSITEELEMENTGUS add constraint FK_CEG_CE foreign key (COMPOSITE_ELEMENT_ID) references RAD3test.COMPOSITEELEMENTIMP (COMPOSITE_ELEMENT_ID);
alter table RAD3test.COMPOSITEELEMENTGUS add constraint FK_CEG_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);

/* COMPOSITEELEMENTIMP */
alter table RAD3test.COMPOSITEELEMENTIMP add constraint FK_CE_ARRAY foreign key (ARRAY_ID) references RAD3test.ARRAY (ARRAY_ID);
alter table RAD3test.COMPOSITEELEMENTIMP add constraint FK_CE_CE foreign key (PARENT_ID) references RAD3test.COMPOSITEELEMENTIMP (COMPOSITE_ELEMENT_ID);
alter table RAD3test.COMPOSITEELEMENTIMP add constraint FK_CMPELIMP_EXTDB foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* COMPOSITEELEMENTRESULTIMP */
alter table RAD3test.COMPOSITEELEMENTRESULTIMP add constraint FK_CERESULT_CELEMENT foreign key (COMPOSITE_ELEMENT_ID) references RAD3test.COMPOSITEELEMENTIMP (COMPOSITE_ELEMENT_ID);
alter table RAD3test.COMPOSITEELEMENTRESULTIMP add constraint FK_CERESULT_QUANT foreign key (QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);

/* CONTROL */
alter table RAD3test.CONTROL add constraint FK_CONTRL_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);
alter table RAD3test.CONTROL add constraint FK_CONTROL_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.CONTROL add constraint FK_CONTROL_ONTO foreign key (CONTROL_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);

/* ELEMENTANNOTATION */
alter table RAD3test.ELEMENTANNOTATION add constraint FK_ELEANNOT_ELEMENTIMP foreign key (ELEMENT_ID) references RAD3test.ELEMENTIMP (ELEMENT_ID);

/* ELEMENTIMP */
alter table RAD3test.ELEMENTIMP add constraint FK_ELEMENT_ARRAY foreign key (ARRAY_ID) references RAD3test.ARRAY (ARRAY_ID);
alter table RAD3test.ELEMENTIMP add constraint FK_ELEMENT_COMPELEFAM foreign key (COMPOSITE_ELEMENT_ID) references RAD3test.COMPOSITEELEMENTIMP (COMPOSITE_ELEMENT_ID);
alter table RAD3test.ELEMENTIMP add constraint FK_ELEMENT_ONTO foreign key (ELEMENT_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.ELEMENTIMP add constraint FK_ELIMP_EXTDB foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* ELEMENTRESULTIMP */
alter table RAD3test.ELEMENTRESULTIMP add constraint FK_ELEMENTRESULT_ELEMENTIMP foreign key (ELEMENT_ID) references RAD3test.ELEMENTIMP (ELEMENT_ID);
alter table RAD3test.ELEMENTRESULTIMP add constraint FK_ELEMENTRESU_QUANT foreign key (QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);
alter table RAD3test.ELEMENTRESULTIMP add constraint FK_ELEMENTRES_SFR foreign key (COMPOSITE_ELEMENT_RESULT_ID) references RAD3test.COMPOSITEELEMENTRESULTIMP (COMPOSITE_ELEMENT_RESULT_ID);

/* LABELMETHOD */
alter table RAD3test.LABELMETHOD add constraint FK_LABELEDMETHOD_PROTO foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);
alter table RAD3test.LABELMETHOD add constraint FK_LABELMETHOD_CHANNEL foreign key (CHANNEL_ID) references RAD3test.CHANNEL (CHANNEL_ID);

/* MAGEDOCUMENTATION */
alter table RAD3test.MAGEDOCUMENTATION add constraint FK_MAGEDOC_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);
alter table RAD3test.MAGEDOCUMENTATION add constraint FK_MDOC_MAGEML foreign key (MAGE_ML_ID) references RAD3test.MAGE_ML (MAGE_ML_ID);

/* MAGE_ML */

/* ONTOLOGYENTRY */
alter table RAD3test.ONTOLOGYENTRY add constraint FK_ONTOLOGYENTRY_PARENT foreign key (PARENT_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.ONTOLOGYENTRY add constraint FK_ONTOLOGYENTRY_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);
alter table RAD3test.ONTOLOGYENTRY add constraint FK_ONTO_EXTDB foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* PROCESSIMPLEMENTATION */
alter table RAD3test.PROCESSIMPLEMENTATION add constraint FK_PROCESSIMP_ONTO foreign key (PROCESS_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);

/* PROCESSIMPLEMENTATIONPARAM */
alter table RAD3test.PROCESSIMPLEMENTATIONPARAM add constraint FK_PRCSIMPPARAM_PRCSIMP foreign key (PROCESS_IMPLEMENTATION_ID) references RAD3test.PROCESSIMPLEMENTATION (PROCESS_IMPLEMENTATION_ID);

/* PROCESSINVOCATION */
alter table RAD3test.PROCESSINVOCATION add constraint FK_PROCESS_PROCIMP foreign key (PROCESS_IMPLEMENTATION_ID) references RAD3test.PROCESSIMPLEMENTATION (PROCESS_IMPLEMENTATION_ID);

/* PROCESSINVOCATIONPARAM */
alter table RAD3test.PROCESSINVOCATIONPARAM add constraint FK_PROCESSINVPARAM_PROCESSINV foreign key (PROCESS_INVOCATION_ID) references RAD3test.PROCESSINVOCATION (PROCESS_INVOCATION_ID);

/* PROCESSINVQUANTIFICATION */
alter table RAD3test.PROCESSINVQUANTIFICATION add constraint FK_PROCESSINQUANT_P foreign key (PROCESS_INVOCATION_ID) references RAD3test.PROCESSINVOCATION (PROCESS_INVOCATION_ID);
alter table RAD3test.PROCESSINVQUANTIFICATION add constraint FK_PROCESSINQUANT_Q foreign key (QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);

/* PROCESSIO */
alter table RAD3test.PROCESSIO add constraint FK_PRCSIO_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);
alter table RAD3test.PROCESSIO add constraint FK_PROCESSEDRESULT21 foreign key (OUTPUT_RESULT_ID) references RAD3test.PROCESSRESULT (PROCESS_RESULT_ID);
alter table RAD3test.PROCESSIO add constraint FK_PROCESSIO_PROCESSINV foreign key (PROCESS_INVOCATION_ID) references RAD3test.PROCESSINVOCATION (PROCESS_INVOCATION_ID);

/* PROCESSIOELEMENT */
alter table RAD3test.PROCESSIOELEMENT add constraint FK_PROCESSIO foreign key (PROCESS_IO_ID) references RAD3test.PROCESSIO (PROCESS_IO_ID);

/* PROCESSRESULT */
alter table RAD3test.PROCESSRESULT add constraint FK_PROCESSRESULT_ONTO foreign key (UNIT_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);

/* PROJECTLINK */
alter table RAD3test.PROJECTLINK add constraint FK_PROJLINK_PROJINFO foreign key (PROJECT_ID) references Coretest.PROJECTINFO (PROJECT_ID);
alter table RAD3test.PROJECTLINK add constraint FK_PROJLINK_TABLEINFO foreign key (TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);

/* PROTOCOL */
alter table RAD3test.PROTOCOL add constraint FK_PROTOCOL_BIBREF foreign key (BIBLIOGRAPHIC_REFERENCE_ID) references SRestest.BIBLIOGRAPHICREFERENCE (BIBLIOGRAPHIC_REFERENCE_ID);
alter table RAD3test.PROTOCOL add constraint FK_PROTOCOL_EXTDBREL foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);
alter table RAD3test.PROTOCOL add constraint FK_PROTOCOL_ONTO foreign key (PROTOCOL_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);

/* PROTOCOLPARAM */
alter table RAD3test.PROTOCOLPARAM add constraint FK_PROTOCOLPARAM_ONTO1 foreign key (DATA_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.PROTOCOLPARAM add constraint FK_PROTOCOLPARAM_ONTO2 foreign key (UNIT_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.PROTOCOLPARAM add constraint FK_PROTOCOLPARAM_PROTO foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);

/* QUANTIFICATION */
alter table RAD3test.QUANTIFICATION add constraint FK_QUANT_ACQ foreign key (ACQUISITION_ID) references RAD3test.ACQUISITION (ACQUISITION_ID);
alter table RAD3test.QUANTIFICATION add constraint FK_QUANT_CONTACT foreign key (OPERATOR_ID) references SRestest.CONTACT (CONTACT_ID);
alter table RAD3test.QUANTIFICATION add constraint FK_QUANT_PROTOCOL foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);
alter table RAD3test.QUANTIFICATION add constraint FK_QUANT_TABLEINFO foreign key (RESULT_TABLE_ID) references Coretest.TABLEINFO (TABLE_ID);

/* QUANTIFICATIONPARAM */
alter table RAD3test.QUANTIFICATIONPARAM add constraint FK_QUANTPARAM_QUANT foreign key (QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);

/* RELATEDACQUISITION */
alter table RAD3test.RELATEDACQUISITION add constraint FK_RELACQ_ACQ01 foreign key (ACQUISITION_ID) references RAD3test.ACQUISITION (ACQUISITION_ID);
alter table RAD3test.RELATEDACQUISITION add constraint FK_RELACQ_ACQ02 foreign key (ASSOCIATED_ACQUISITION_ID) references RAD3test.ACQUISITION (ACQUISITION_ID);

/* RELATEDQUANTIFICATION */
alter table RAD3test.RELATEDQUANTIFICATION add constraint FK_RELQUANT_QUANT01 foreign key (QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);
alter table RAD3test.RELATEDQUANTIFICATION add constraint FK_RELQUANT_QUANT02 foreign key (ASSOCIATED_QUANTIFICATION_ID) references RAD3test.QUANTIFICATION (QUANTIFICATION_ID);

/* STUDY */
alter table RAD3test.STUDY add constraint FK_STUDY_BIBREF foreign key (BIBLIOGRAPHIC_REFERENCE_ID) references SRestest.BIBLIOGRAPHICREFERENCE (BIBLIOGRAPHIC_REFERENCE_ID);
alter table RAD3test.STUDY add constraint FK_STUDY_CONTACT foreign key (CONTACT_ID) references SRestest.CONTACT (CONTACT_ID);
alter table RAD3test.STUDY add constraint FK_STUDY_EXTDBRELEASE foreign key (EXTERNAL_DATABASE_RELEASE_ID) references SRestest.EXTERNALDATABASERELEASE (EXTERNAL_DATABASE_RELEASE_ID);

/* STUDYASSAY */
alter table RAD3test.STUDYASSAY add constraint FK_STDYASSAY_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.STUDYASSAY add constraint FK_STDYASSAY_STDY foreign key (STUDY_ID) references RAD3test.STUDY (STUDY_ID);

/* STUDYDESIGN */
alter table RAD3test.STUDYDESIGN add constraint FK_STDYDES_STDY foreign key (STUDY_ID) references RAD3test.STUDY (STUDY_ID);

/* STUDYDESIGNASSAY */
alter table RAD3test.STUDYDESIGNASSAY add constraint FK_STDYDESASSAY_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.STUDYDESIGNASSAY add constraint FK_STDYDESASSAY_STDYDES foreign key (STUDY_DESIGN_ID) references RAD3test.STUDYDESIGN (STUDY_DESIGN_ID);

/* STUDYDESIGNDESCRIPTION */
alter table RAD3test.STUDYDESIGNDESCRIPTION add constraint FK_STDYDESDCR_STDYDES foreign key (STUDY_DESIGN_ID) references RAD3test.STUDYDESIGN (STUDY_DESIGN_ID);

/* STUDYDESIGNTYPE */
alter table RAD3test.STUDYDESIGNTYPE add constraint FK_STDYDESTYPE_ONTO foreign key (ONTOLOGY_ENTRY_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.STUDYDESIGNTYPE add constraint FK_STDYDESTYPE_STDYDES foreign key (STUDY_DESIGN_ID) references RAD3test.STUDYDESIGN (STUDY_DESIGN_ID);

/* STUDYFACTOR */
alter table RAD3test.STUDYFACTOR add constraint FK_STDYFCTR_ONTO foreign key (STUDY_FACTOR_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.STUDYFACTOR add constraint FK_STDYFCTR_STDYDES foreign key (STUDY_DESIGN_ID) references RAD3test.STUDYDESIGN (STUDY_DESIGN_ID);

/* STUDYFACTORVALUE */
alter table RAD3test.STUDYFACTORVALUE add constraint FK_STDYFCTRVAL_ASSAY foreign key (ASSAY_ID) references RAD3test.ASSAY (ASSAY_ID);
alter table RAD3test.STUDYFACTORVALUE add constraint FK_STDYFCTRVAL_STDYFCTR foreign key (STUDY_FACTOR_ID) references RAD3test.STUDYFACTOR (STUDY_FACTOR_ID);

/* TREATMENT */
alter table RAD3test.TREATMENT add constraint FK_TREATMENT6 foreign key (BIO_MATERIAL_ID) references RAD3test.BIOMATERIALIMP (BIO_MATERIAL_ID);
alter table RAD3test.TREATMENT add constraint FK_TREATMENT7 foreign key (TREATMENT_TYPE_ID) references RAD3test.ONTOLOGYENTRY (ONTOLOGY_ENTRY_ID);
alter table RAD3test.TREATMENT add constraint FK_TREATMEN_PROTOCOL foreign key (PROTOCOL_ID) references RAD3test.PROTOCOL (PROTOCOL_ID);

/* TREATMENTPARAM */
alter table RAD3test.TREATMENTPARAM add constraint FK_TREATMENTPARAM_PRTOPRM foreign key (PROTOCOL_PARAM_ID) references RAD3test.PROTOCOLPARAM (PROTOCOL_PARAM_ID);
alter table RAD3test.TREATMENTPARAM add constraint FK_TREATMENTPARAM_TREATMENT foreign key (TREATMENT_ID) references RAD3test.TREATMENT (TREATMENT_ID);



/* 112 non-primary key constraint(s) */

SPOOL OFF
SET ECHO OFF
DISCONNECT
EXIT
