#!/usr/bin/tcsh



set srr_ids = $argv[1]      #This is a FILE containing a list of SRR ids
set sra_samples = $argv[2]  #This is a FILE containing a 2-column list showing '<subset_name>	 <full_sample_name>' (NOTE: In this script, subset_name == SRR id)
set picard_dir = $argv[3]   #This should point to the version of picard to use...due to some custom modifications made for us by the author, this needs to be: $ENV{XGENOME_SW_LEGACY_JAVA}/samtools/picard-tools-1.27
set tmp_dir = $argv[4]      #This points to a temporary working directory created by: Genome::Sys->create_temp_directory
set ascp_user = $argv[5]
set ascp_pw = $argv[6]
set pwd = `pwd`

echo "Checking for appropriate scripts..."

#NOTE: currently, the fastq-dump install in the bin is an old version that does NOT work with the new SRA objects...so I'm using a local copy
####set fastq_dump = `which fastq-dump | awk '{print NF}'`
set fastq_dump = `ls /gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/SRA_TOOLKIT/sra_toolkit/sratoolkit.2.1.9-centos_linux64/fastq-dump.2.1.9 | awk '{print NF}'`

set trimBWA = `which trimBWAstyle.usingBam.pl | awk '{print NF}'`
set samtools = `which samtools | awk '{print NF}'`
setenv ASPERA_SCP_PASS $ascp_pw

if ( $fastq_dump > 1 ) then 
        echo "Could not find fastq-dump.  Please make sure this is in your path and try again."
        exit
endif

if ( $trimBWA > 1 ) then
	echo "Could not find trimBWAstyle.usingBAM.pl.  Please make sure this is in your path and try again."
	exit
endif

if ( $samtools > 1 ) then 
        echo "Could not find samtools.  Please make sure this is in your path and try again."
        exit
endif
echo ""

foreach sample ( `grep -f $srr_ids $sra_samples | awk '{print $2}' | sort | uniq` )

	#Number of runs in this sample
	set runs = `grep $sample $sra_samples | awk '{print $1}' | sort | uniq | wc | awk '{print $1}'`
	
       	echo "`date` ${sample}: Processing $runs run(s)..."

	if ( -d $sample ) then
	    echo "`date` ${sample}: Processing already started..."
	else
	    mkdir $sample
	endif






##############################
############################## This block of code basically extracts fastq from SRA objects, and then builds bam file for rest of script vvvv
##############################

	#Extract fastq from SRA object & build BAM file

	set sn = "sn"
	set ri = "ri"
	set sum = 0
	set failed = 0

	foreach srr_id ( `grep $sample $sra_samples | awk '{print $1}' | sort | uniq` )

		if ($failed) continue

		#Pull meta data if it does not exist
		if (! -e ${sample}/$srr_id.xml) then
		    echo "\t`date` ${srr_id}: Pulling meta data..."		
		    wget 'http://www.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?run='$srr_id'&retmode=xml' -O ${sample}/$srr_id.xml >& /dev/null
		else
		    echo "\t`date` ${srr_id}: Meta data exists."
		endif

		#Check to see if SRA has been converted to fastq
		if (-e ${sample}/$srr_id.fastq-dump) then
			#NOTE: new version of fastq-dump (v2.1.9) no longer dumps same format STDOUT as before, need to change this ... jmartin 120127
			####set dumped = `grep Success ${sample}/$srr_id.fastq-dump | wc | awk '{print $1}'`
			set dumped = `grep "spots total" ${sample}/$srr_id.fastq-dump | wc | awk '{print $1}'`
		else
			set dumped = 0
		endif

		#If fastqs have not been created, run fastq-dump
		if ( $dumped > 0 && -e ${sample}/${srr_id}_1.masked && -e ${sample}/${srr_id}_2.masked ) then
			#Fastq dump was sucessful
			#NOTE: new version of fastq-dump (v2.1.9) no longer dumps same format STDOUT as before, so this was changed ... jmartin 120127
			####set reads = `grep Success $sample/${srr_id}.fastq-dump | awk '{print $7}'`
			set reads = `grep "spots total" ${sample}/$srr_id.fastq-dump | awk '{print $2}'`
                        @ sum += `echo $reads`


			#NOTE: Due to the new fastq-dump removing unpaired reads, this $sum may not account for those reads (since the STDOUT dump is probably showing ALL reads)...may need to fix this if I want to really be able to short-circuit this step ... jmartin 120129
			echo "ERROR: IF YOU GET THIS MESSAGE, THE FASTQ FILES WERE DETEREMINED TO ALREADY EXIST AND THIS STEP WAS SHORT CIRCUITED...BUT THE sum READ COUNT IS PROBABLY INACCURATE BECAUSE THE SCRIPT DOES NOT SUBTRACT OUT THE UNPAIRED READ COUNT FROM THE UNPAIRED READ FILE GENERATED BY THE NEW fastq-dump (v2.1.9) ... I will force this to FAIL"
			echo "\tERROR: Fastq already extracted for ${srr_id} ... but did not subtract unpaired file count from sum"
			set failed = 1
			continue
			#exit


                        set masked = `cat $sample/${srr_id}*masked | awk '{print $1}' | perl -ne '$sum += $_; if (eof) {print $sum;}'`
                        set mbases = `cat $sample/${srr_id}*masked | awk '{print $2}' | perl -ne '$sum += $_; if (eof) {print $sum;}'`
                        echo "\t`date` ${srr_id}: $masked total reads masked $mbases total bases masked."
			echo "\t`date` ${srr_id}: $reads pairs already dumped successfully."
		else
			#Check that data has been downloaded
			if (! -e ${srr_id}) then
				echo "\tERROR: No SRA data for ${srr_id}"
				set failed = 1
				continue
				#exit
			endif





			#NOTE: Previously at this point I'd check the downloaded SRA object files for integrity, but the new SRA
			#      object files I'm downloading don't come with md5 signatures




			#NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)
			#NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)
			#NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)



			#Dump fastq files from SRA
			echo "\t`date` ${srr_id}: Pulling Fastqs from SRA data..."
			#NOTE: For now, I'm using a local installation of the latest version of fastq-dump, since the one installed in the bin doesn't work for the new SRA objects ... jmartin 120126
			####fastq-dump -E -A $srr_id -D $srr_id/ -DB '@$sn/$ri' -DQ '+$sn/$ri' -O $sample/ >& $sample/$srr_id.fastq-dump
			#NOTE: Because I have to handle both OLD and NEW format SRA objects, I need to determine which I'm working with for each SRR id, and run the command in the appropriate way
			set srr_dir_content_count = `ls ${srr_id}/* | wc | awk '{print $1}'`
			if ( $srr_dir_content_count == 1 ) then
			        #This is a NEW format SRA object
				/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/SRA_TOOLKIT/sra_toolkit/sratoolkit.2.1.9-centos_linux64/fastq-dump.2.1.9 -E -A $srr_id --defline-seq '@$sn/$ri' --defline-qual '+$sn/$ri' --split-3 -O ${sample}/ ${srr_id}/$srr_id.sra >& ${sample}/$srr_id.fastq-dump
			else
				#This is an OLD format SRA object
				/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/SRA_TOOLKIT/sra_toolkit/sratoolkit.2.1.9-centos_linux64/fastq-dump.2.1.9 -E -A $srr_id --defline-seq '@$sn/$ri' --defline-qual '+$sn/$ri' --split-3 -O ${sample}/ >& ${sample}/$srr_id.fastq-dump
			endif

#NOTE: This produces *_1.fastq, *_2.fastq & *.fastq ... but the unpaired reads directly from the SRA can be ignored, so I only care about harvesting *_1.fastq & *_2.fastq
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
####HOW TO USE fastq-dump.2.1.9 ON NEW SRA OBJECTS (w/ paired end output)
####/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/SRA_TOOLKIT/sra_toolkit/sratoolkit.2.1.9-centos_linux64/fastq-dump.2.1.9 -E -A SRR346683 --defline-seq '@$sn/$ri' --defline-qual '+$sn/$ri' --split-3 -O test_newFQD_on_new_format_SRA/ SRR346683/SRR346683.sra > OUTPUT.new_on_new

####HOW TO USE fastq-dump.2.1.9 ON OLD SRA OBJECTS (w/ paired end output)
####/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/SRA_TOOLKIT/sra_toolkit/sratoolkit.2.1.9-centos_linux64/fastq-dump.2.1.9 -E -A SRR061372 --defline-seq '@$sn/$ri' --defline-qual '+$sn/$ri' --split-3 -O test_newFQD_on_old_format_SRA/ > OUTPUT.new_on_old

#****main difference between using 2.1.9 on new & old is that with the new format, I need to specify path to the actual .sra file (the SRA object), but with the old format it expects the SRA object to be sitting in the proper hierarchy under the -A (accession ... the SRR id folder)








####DEBUG
echo "cat-ing contents of .fastq-dump file for > $srr_id <"
cat ${sample}/$srr_id.fastq-dump
echo "done cat-ing contents of .fastq-dump file for > $srr_id <"

set current_directory = `pwd`
echo "for >$srr_id< we are in the directory >$current_directory<"

####echo "I am now sleeping for 99999 seconds (over 1 day) so that you can look at the discard .fastq file to check for NNNNN reads (i.e. human contam reads that need to be removed)"
####sleep 99999

####DEBUG







			#Check that reads were dumped correctly
			#NOTE: new version of fastq-dump (v2.1.9) no longer dumps same format STDOUT as before, need to change this ... jmartin 120127
			####set reads = `grep Success ${sample}/${srr_id}.fastq-dump | awk '{print $7}'`
			set reads = `grep "spots total" ${sample}/${srr_id}.fastq-dump | awk '{print $2}'`
			if ($reads < 1) then
				echo "\tERROR ${srr_id}: fastq-dump failed"
				set failed = 1
				continue
				#exit
			else
				echo "\t`date` ${srr_id}: $reads pairs dumped successfully."
				@ sum += `echo $reads`
				if ( ! -e ${sample}/${srr_id}_1.fastq || ! -e ${sample}/${srr_id}_2.fastq ) then
					echo "\tERROR ${srr_id}: Read one and read two files were not downloaded properly.  Check that NCBI has both ends for this run."
					set failed = 1
					continue
				endif
			endif

			#Count number of human masked reads ... NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)
			#Count number of human masked reads ... NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)
			#Count number of human masked reads ... NOTE: AS LONG AS 'fastq-dump' IS USING THE -E ARGUMENT, NO 100% MASKED-BY-'N' SEQUENCES WILL BE IN FASTQ DATA!!!! (jmartin 120221)
			echo "\t`date` ${srr_id}: Counting masked reads..."
 			perl -ne 'chomp; $count = tr/N/n/; if ($count == length $_) { $masked++; $b += $count;} if (eof){ print "$masked\t$b\n";}' $sample/${srr_id}_1.fastq > $sample/${srr_id}_1.masked
 			perl -ne 'chomp; $count = tr/N/n/; if ($count == length $_) { $masked++; $b += $count;} if (eof){ print "$masked\t$b\n";}' $sample/${srr_id}_2.fastq > $sample/${srr_id}_2.masked
                        set masked = `cat $sample/${srr_id}*masked | awk '{print $1}' | perl -ne '$sum += $_; if (eof) {print $sum;}'`
                        set mbases = `cat $sample/${srr_id}*masked | awk '{print $2}' | perl -ne '$sum += $_; if (eof) {print $sum;}'`
			echo "\t`date` ${srr_id}: $masked total reads masked $mbases total bases masked."

			echo "\t`date` ${srr_id}: Appending fastqs to sample file..."

			#Concatenate the fastqs into one sample
			touch ${sample}/${sample}_1.fastq
			touch ${sample}/${sample}_2.fastq
			cat ${sample}/${srr_id}_1.fastq >> ${sample}/${sample}_1.fastq
			cat ${sample}/${srr_id}_2.fastq >> ${sample}/${sample}_2.fastq



#########  TESTING THIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! (not yet sure its correct)
			echo "sum BEFORE removing the discarded count: $sum"

			#Correct the # reads tracked in $sum since we discard the unpaired reads
			set discarded_reads = `wc ${sample}/${srr_id}.fastq`

			echo "discarded_reads: $discarded_reads"

			echo "GOT TO HERE 1"

			#NOTE: This only works for fastq that fits on a SINGLE LINE (i.e. up to 100mers so far) ... jmartin 120129
			@ discarded_reads /= 4

			echo "GOT TO HERE 2"

			@ sum -= $discarded_reads

			echo "sum AFTER removing the discarded count: $sum"
#########  TESTING THIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! (not yet sure its correct)




			#Remove the fastqs
			echo "\t`date` ${srr_id}: Removing fastqs..."
			rm ${sample}/${srr_id}_1.fastq
			rm ${sample}/${srr_id}_2.fastq
			#New version of fastq-dump (v2.1.9) produces this unpaired file in addition to paired files, need to clean it up as well
			rm ${sample}/${srr_id}.fastq

		endif
	end

	#Check fail status
	if ($failed) then
		echo "`date` ${sample}: Some runs are not available.  SKIPPING"
		echo ""
		continue
	endif

	#Converting fastqs into a BAM
	echo "`date` ${sample}: Converting Fastq to BAM..."
	if (! -e $sample/$sample.bam) then
		java -jar $picard_dir/FastqToSam.jar F1=$sample/{$sample}_1.fastq F2=$sample/${sample}_2.fastq O=${sample}/$sample.bam V=Standard SAMPLE_NAME=$sample TMP_DIR=$tmp_dir >& ${sample}/FastqToSam.out
	else
		echo "\tSKIPPING: $sample/$sample.bam exists."
	endif

	#Checking that BAM is complete
	if (-e $sample/FastqToSam.out) then
		set bamReads = `grep Processed $sample/FastqToSam.out | awk '{print $2}'`
	else 
		set bamReads = 0
	endif

	if ( $sum == $bamReads ) then
		if ( -e $sample/${sample}_1.fastq ) then		
			echo "\tRemoving sample fastqs: $sample/${sample}_1.fastq $sample/${sample}_2.fastq"
			rm $sample/*.fastq
		endif
	else
		echo "\tERROR: BAM file reads ($bamReads) do not match SRA dumped reads ($sum)."
		exit
	endif

	#Now I do a QUERY-NAME based sort of the bam file using Picard's SortSam.jar
	set cmd_nameBased_sort = "java -jar $picard_dir/SortSam.jar I=${sample}/$sample.bam O=${sample}/$sample.SSsort.bam TMP_DIR=$tmp_dir SORT_ORDER=queryname"
	$cmd_nameBased_sort
	if (-e ${sample}/$sample.SSsort.bam) then
	    echo "`date` ${sample}: Name-based sort of bam file (via SortSam.jar) successful"
	else
	    echo "`date` ${sample}: ERROR: failed to do name-based sort (via SortSam.jar) on merged bam file"
	    exit
	endif

##############################
############################## This block of code basically extracts fastq from SRA objects, and then builds bam file for rest of script ^^^^
##############################






	#Removing Duplicates
	echo "`date` ${sample}: Removing duplicates..."

	if ( -e ${sample}/$sample.denovo_duplicates_marked.bam ) then
		if ( -e  $sample/EstimateLibraryComplexity.out ) then
		    if ( `grep "done" $sample/EstimateLibraryComplexity.out | wc | awk '{print $1}'` > 0 ) then
			echo "\tSKIPPING: $sample/$sample.denovo_duplicates_marked.bam exists"
		    else
			echo "\tERROR: EstimateLibraryComplexity did not complete.  Please delete ${sample}/$sample.denovo_duplicates_marked.bam and $sample/EstimateLibraryComplexity.out and try again"
			exit
		    endif
	        else 
		    echo "\tERROR: EstimateLibraryComplexity did not complete.  Please delete ${sample}/$sample.denovo_duplicates_marked.bam and $sample/EstimateLibraryComplexity.out and try again"
		    exit
		endif
	else
		#___Modified to force specific memory allocation, and to turn off java garbage collection timeout ... jmartin 100907
####		java -Xmx43g -XX:-UseGCOverheadLimit -jar $picard_dir/EstimateLibraryComplexity.jar I=${sample}/$sample.bam O=${sample}/$sample.denovo_duplicates_marked.bam METRICS_FILE=${sample}/$sample.denovo_duplicates_marked.metrics REMOVE_DUPLICATES=true TMP_DIR=$tmp_dir >& ${sample}/EstimateLibraryComplexity.out
		#___Modified to use 60Gb memory allocation to see if this helped eliminate the truncated bam files being produced ... jmartin 111108
		####java -Xmx60g -XX:-UseGCOverheadLimit -jar $picard_dir/EstimateLibraryComplexity.jar I=${sample}/$sample.bam O=${sample}/$sample.denovo_duplicates_marked.bam METRICS_FILE=${sample}/$sample.denovo_duplicates_marked.metrics REMOVE_DUPLICATES=true TMP_DIR=$tmp_dir >& ${sample}/EstimateLibraryComplexity.out
		#___Modified to use SORTED bam file ... jmartin 111114
		java -Xmx60g -XX:-UseGCOverheadLimit -jar $picard_dir/EstimateLibraryComplexity.jar I=${sample}/$sample.SSsort.bam O=${sample}/$sample.denovo_duplicates_marked.bam METRICS_FILE=${sample}/$sample.denovo_duplicates_marked.metrics REMOVE_DUPLICATES=true TMP_DIR=$tmp_dir >& ${sample}/EstimateLibraryComplexity.out
		samtools flagstat ${sample}/$sample.denovo_duplicates_marked.bam > ${sample}/$sample.denovo_duplicates_marked.counts
        endif
	
	#Changed this to reflect new formatting of samtools flagstats ... jmartin 120130
	####set nondupReads = `awk '$2 ~ /paired/ {print $1}' $sample/$sample.denovo_duplicates_marked.counts`
	set nondupReads = `awk '$4 ~ /paired/ {print $1}' $sample/$sample.denovo_duplicates_marked.counts`

	echo "`date` ${sample}: $nondupReads left after duplication removal"
	
	#Trimming low quality and masked reads
	echo "`date` ${sample}: Trimming Q2 bases..."
	if ( ! -e ${sample}/${sample}.denovo_duplicates_marked.trimmed.1.fastq.bz2 ) then



####DEBUG
echo "inside trimBWAstyle.usingBam.pl ... before running script"
####DEBUG


		trimBWAstyle.usingBam.pl -o 33 -q 3 -f ${sample}/$sample.denovo_duplicates_marked.bam > ${sample}/trimBWAstyle.out

####DEBUG
echo "inside trimBWAstyle.usingBam.pl ... after running script"
set current_location = `pwd`
echo "current_location is: $current_location"
echo "trimmed bam file should be at $current_location / ${sample}/$sample.denovo_duplicates_marked.bam"
####DEBUG




		set qualReads = `grep reads ${sample}/trimBWAstyle.out | awk '{print $3}'`
		set qualBases = `grep bases ${sample}/trimBWAstyle.out | awk '{print $3}'`
		echo "`date` ${sample}: $qualReads reads ($qualBases bases) left after trimming" 
		echo "`date` ${sample}: Compressing trimmed files..."
		bzip2 ${sample}/${sample}.denovo_duplicates_marked.trimmed.*.fastq

####DEBUG
set current_dir_list = `ls`
echo "after bzip2 operation on the trimmed fastq files ... here is a directory listing: $current_dir_list"
####DEBUG



	else 
		echo "\tSKIPPING: ${sample}/$sample.duplicates_removed.Q2trimmed.fastq.bz2 exists."
                set qualReads = `grep reads ${sample}/trimBWAstyle.out | awk '{print $3}'`
                set qualBases = `grep bases ${sample}/trimBWAstyle.out | awk '{print $3}'`
                echo "`date` ${sample}: $qualReads reads ($qualBases bases) left after trimming"
	endif

	echo "`date` ${sample}: Creating checksum files..."
	if (! -e ${sample}/${sample}.md5) then
		md5sum ${sample}/*.bz2 > ${sample}/$sample.md5
	else
		echo "\tSKIPPING: ${sample}/$sample.md5 exists"
	endif





################### NOTE: This data upload to the DACC copies data from the TMP directory, so it isn't available after processing ends...Thus, if you do test runs with this block turned off, and then you want to go ahead and do the uploads, you will need to rerun this from scratch





	#This part of the script handles data uploads to the DACC
	echo "`date` ${sample}: Uploading files to DACC..."
        if (! -e ${sample}/${sample}.ascp) then
		ascp -QTd -l100M $sample/*.md5 $sample/*.xml $sample/*.bz2 $ascp_user@aspera.hmpdacc.org:/WholeMetagenomic/06-ProductionPhaseII/$sample/ > $sample/$sample.ascp
	else
		set files = `grep files ${sample}/${sample}.ascp | awk '{print $4}'`
		if ( $files > 4 ) then
			echo "\tSKIPPING: $sample transfered."
		else
			ascp -QTd -l100M $sample/*.md5 $sample/*.xml $sample/*.bz2 $ascp_user@aspera.hmpdacc.org:/WholeMetagenomic/06-ProductionPhaseII/$sample/ > $sample/$sample.ascp
	        endif
	endif



	#This part of the script handles data uploads to the DACC ... This block saved in comment to show where we ORIGINALLY were placing things on the DACC ... jmartin 120223
####	echo "`date` ${sample}: Uploading files to DACC..."
####	if (! -e ${sample}/${sample}.ascp) then
####		ascp -QTd -l100M $sample/*.md5 $sample/*.xml $sample/*.bz2 $ascp_user@aspera.hmpdacc.org:/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly/$sample/ > $sample/$sample.ascp
####	else
####		set files = `grep files ${sample}/${sample}.ascp | awk '{print $4}'`
####		if ( $files > 4 ) then
####			echo "\tSKIPPING: $sample transfered."
####		else
####			ascp -QTd -l100M $sample/*.md5 $sample/*.xml $sample/*.bz2 $ascp_user@aspera.hmpdacc.org:/WholeMetagenomic/02-ScreenedReads/ProcessedForAssembly/$sample/ > $sample/$sample.ascp
####		endif		
####	endif






	#Processing engine script ending
	echo "`date` ${sample}: Processing complete."
end
