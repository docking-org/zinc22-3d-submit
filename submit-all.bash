#!/bin/bash

# req: INPUT_FILE
# req: OUTPUT_DEST

# opt: MAX_PARALLEL
# opt: MAX_BATCHES
# opt: LINES_PER_BATCH
# opt: LINES_PER_JOB
# opt: QSUB_ARGS

BINDIR=$(dirname $0)
BINDIR=${BINDIR-.}

if ! [[ "$BINDIR" == /* ]]; then
	BINDIR=$PWD/$BINDIR
fi

function log {
	echo "[submit-all $(date +%X)]: " $@
}

function mkd {
	if ! [ -d $1 ]; then
		mkdir -p $1
	fi
}

function exists {
	env_name=$1
	desc=$2
	if [ -z "${!env_name}" ]; then
		echo "expected env arg: $env_name"
		echo "arg description: $desc" 
		failed=1
	fi
}

function exists_warning {
	env_name=$1
	desc=$2
	default=$3
	if [ -z "${!env_name}" ]; then
		echo "optional env arg missing: $env_name"
		echo "arg description: $desc"
		echo "defaulting to $default"
		export $env_name="$default"
	fi
}

failed=0
echo # required parameters
exists INPUT_FILE "input SMILES for 3d building"
exists OUTPUT_DEST "destination for db2, logs, split input files"
exists SOFT_HOME "directory where software is stored"
exists LICENSE_HOME "directory where licenses are stored"
echo # optional parameters
exists_warning OMEGA_MAX_CONFS "maximum conformers generated by OMEGA" 600
exists_warning OMEGA_ENERGY_WINDOW "..." 12
exists_warning OMEGA_TORLIB "..." Original
exists_warning OMEGA_FF "..." MMFF94Smod
exists_warning OMEGA_RMSD "..." 0.5
exists_warning CORINA_MAX_CONFS "maximum confs generated by corina" 1
exists_warning SHRTCACHE "short term storage for working files" /dev/shm
exists_warning LONGCACHE "long term storage for program files" /tmp
exists_warning MAX_BATCHES "max no. of job arrays submitted at one time" 25
exists_warning LINES_PER_BATCH "number of SMILES per job array batch" 50000
exists_warning LINES_PER_JOB "number of SMILES per job array element" 50
#exists_warning BATCH_RESUBMIT_THRESHOLD "minimum percentage of entries in an array batch that are complete before batch is considered complete" 95
exists_warning BUILD_MOL2 "if set to \"true\" build from mol2 files instead of smiles. input entries should be paths to mol2 files instead of smiles" false
exists_warning SKIP_OMEGA "skip omega conformer generation- use just the input conformation if using BUILD_MOL2 or the one generated by corina if not" ""
echo # software parameters
for soft_prefix in dock jchem corina pyenv openbabel extralibs; do
	latest=$(readlink $SOFT_HOME/${soft_prefix}-latest)
	soft_prefix_upper=$(echo $soft_prefix | tr '[:lower:]' '[:upper:]')
	soft_varname=${soft_prefix_upper}_VERSION
	soft_varvalu=${!soft_varname}
	latest_basename=$(echo $latest | rev | cut -d'.' -f3- | rev)
	if [ -z $soft_varvalu ]; then
		echo export ${soft_varname}=${latest_basename}
		export ${soft_varname}=${latest_basename}
	elif [ $soft_varvalu != $latest_basename ]; then
		echo "warning: $soft_varname (${!soft_varname}) is not set to latest version ($latest)"
	fi
done
#exists_warning DOCK_VERSION "version of UCSF DOCK ligand pipeline software to use" DOCK.3.8.4.2.3d
#exists_warning JCHEM_VERSION "version of chemaxon jchem software to use" jchem-19.15.r0
#exists_warning CORINA_VERSION "version of corina to use" corina-2025
#exists_warning PYENV_VERSION "python environment to use" lig_build_py3-3.7.1
echo

required_vars="INPUT_FILE OUTPUT_DEST SOFT_HOME LICENSE_HOME"
optional_vars="SHRTCACHE LONGCACHE MAX_BATCHES LINES_PER_BATCH LINES_PER_JOB BATCH_RESUBMIT_THRESHOLD BUILD_MOL2 SKIP_OMEGA OMEGA_MAX_CONFS CORINA_MAX_CONFS OMEGA_ENERGY_WINDOW OMEGA_TORLIB OMEGA_FF OMEGA_RMSD"
software_vars="DOCK_VERSION JCHEM_VERSION PYENV_VERSION CORINA_VERSION OPENBABEL_VERSION EXTRALIBS_VERSION"
all_vars="$required_vars $optional_vars $software_vars"

JOBS_PER_BATCH=$((LINES_PER_BATCH/LINES_PER_JOB))

[ $failed -eq 1 ] && exit

export INPUT_FILENAME=$(basename $INPUT_FILE)
export OUTPUT_DEST=$OUTPUT_DEST/$INPUT_FILENAME.batch-3d.d

mkd $OUTPUT_DEST/in
mkd $OUTPUT_DEST/out
mkd $OUTPUT_DEST/log

log "splitting file into sub-batches of $LINES_PER_BATCH..."

if [ `ls $OUTPUT_DEST/in | wc -l` -eq 0 ]; then
split --suffix-length=3 --lines=$LINES_PER_BATCH $INPUT_FILE $OUTPUT_DEST/in/
fi

for batch_50K in $OUTPUT_DEST/in/*; do
	if [ -d $batch_50K ]; then
		continue
	fi	

	log "processing batch: $batch_50K"
	batch_name=$(basename $batch_50K)

	export OUTPUT=$OUTPUT_DEST/out/$batch_name.d
	export LOGGING=$OUTPUT_DEST/log/$batch_name.d
	export INPUT=$batch_50K.d

	if ! [ -d $INPUT ]; then
		mkdir $INPUT
		split --suffix-length=3 --lines=$LINES_PER_JOB $batch_50K $INPUT/
	fi

	function count_files {
		ls $1 | wc -l
	}

	# it tends to be faster (if supported) to use du -s --inodes to count entries, as ls | wc -l can be slow
	#n_submit=$(count_files $INPUT)
	#if [ -d $INPUT/resubmit ]; then
	#	n_resubmit=$(count_files $INPUT/resubmit)
	#	n_submit=$((n_submit-n_resubmit)) # -1 because du counts the directory iteslf for no. of inodes
	#fi

	if [ -d $OUTPUT ]; then
		#n_present=$(count_files $OUTPUT)
		#if [ -d $OUTPUT/save ]; then
		#	n_save=$(count_files $OUTPUT/save)
		#	n_present=$((n_present-n_save)) # -1 -1 because du counts the directory iteslf for no. of inodes
		#fi

		export RESUBMIT=TRUE
		log "checking existing output..."
		alli=/dev/shm/all_input_$(whoami)_$(date +%s)
		allia=/dev/shm/all_input_annotated_$(whoami)_$(date +%s)
		allo=/dev/shm/all_output_$(whoami)_$(date +%s)
		missing=/dev/shm/all_missing_$(whoami)_$(date +%s)
		ls $INPUT/??? | xargs -n 1 basename | sort | awk '{print $1 " " NR}' | tee $allia | awk '{print $2}' > $alli
		ls $OUTPUT/*.tar.gz 2>/dev/null | xargs -n 1 basename 2>/dev/null | sort | cut -d'.' -f1 > $allo

		sort -n $alli $allo | uniq -u > $missing
		n_present=$(cat $allo | wc -l)
		n_submit=$(cat $alli | wc -l)

		# removing this for now- is weird and doesn't work right

		#echo $n_submit $BATCH_RESUBMIT_THRESHOLD
		#echo $((n_submit-n_present)) $(((BATCH_RESUBMIT_THRESHOLD * n_submit)/100))
		#if [ $((n_submit-n_present)) -le $((n_submit-(BATCH_RESUBMIT_THRESHOLD * n_submit)/100)) ]; then
                #       log "this batch looks mostly done: ($((n_submit-n_present))) missing... moving on!"
                #       continue
                #fi

		rm $alli $allo

		if [ $n_present -eq $n_submit ]; then
			echo "this batch looks all done! moving on..."
		fi
		
		#all_input=$(ls -l $INPUT | tail -n+2 | grep -v "^d" | awk '{print $9}')
		#present=$(ls $OUTPUT | cut -d'.' -f1 | sort -n)
		#all=$(seq 1 $n_submit)
		#missing=$(printf "$present\n$all\n" | sort -n | uniq -u)

		if [ -d $INPUT/resubmit ]; then rm -r $INPUT/resubmit; fi

		mkdir $INPUT/resubmit
		for m in $(cat $missing); do
			infile=$(cat $allia | grep -w $m | awk '{print $1}')
			#infile=$(printf "$all_input" | tr '\n' ' ' | cut -d' ' -f$m)
			ln -s $INPUT/$infile $INPUT/resubmit/$m
		done
		n_submit=$(cat $missing | wc -l)
		rm $allia

		log "resubmitting $n_submit failed items of $batch_50K"
	else
		n_submit=$(ls $INPUT/??? | wc -l)
		log "submitting $n_submit items of $batch_50K"
		export RESUBMIT=
	fi

	mkdir -p $OUTPUT
	mkdir -p $LOGGING

	SBATCH_ARGS=${SBATCH_ARGS-"--time=02:00:00"}
	BUILD_SCRIPT="build-3d.bash"
	#if ! [ $BUILD_MOL2 = "true" ]; then
	#	BUILD_SCRIPT="build-3d.bash"
	#else
	#	BUILD_SCRIPT="build-3d-mol2.bash"
	#fi

	function wait_jobs_slurm {
		n_uniq=0
		once=true
		while [ "$n_uniq" -ge $MAX_BATCHES ] || ! [ -z $once ]; do
			[ -z $once ] && sleep 120
			n_uniq=`squeue -u $(whoami) | tail -n+2 | grep batch_3d | awk '{print $1}' | cut -d'_' -f1 | sort -u | wc -l`
			n_jobs=`squeue -u $(whoami) | tail -n+2 | grep batch_3d | wc -l`
			n_jobs=$((n_jobs-n_uniq))
			log "$n_uniq batches submitted, $n_jobs jobs running"
			once=
		done
		log n_jobs=$n_jobs
	}

	function wait_jobs_sge {
		n_uniq=0
		once=true
		while [ $n_uniq -ge $MAX_BATCHES ] || ! [ -z $once ]; do
			[ -z $once ] && sleep 120
			n_uniq=`qstat | tail -n+3 | grep batch_3d | awk '{print $1}' | sort -u | wc -l`
			n_jobs=`qstat | tail -n+3 | grep batch_3d | wc -l`
			n_jobs=$((n_jobs-n_uniq))
			log "$n_uniq batches submitted, $n_jobs jobs running"
			once=
		done
		log n_jobs=$n_jobs
	}

	var_args=
	slurm_var_args=
	for var in $all_vars INPUT OUTPUT LOGGING RESUBMIT; do
		if [ -z "$var_args" ]; then
			var_args="-v $var=${!var}"
			slurm_var_args="$var=${!var}"
		else
			var_args="$var_args -v $var=${!var}"
			slurm_var_args="$slurm_var_args,$var=${!var}"
		fi
	done
	# it's really annoying, but it needs to be done
	# user defined PATH variables seem to screw up the pipeline (particularly conda python environments overriding our pipeline-specific one)
	basicpath="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
	var_args="$var_args -v PATH=$basicpath"
	slurm_var_args="$slurm_var_args,PATH=$basicpath"

	if [ "$SUBMIT_MODE" = "SGE" ]; then
		echo     qsub $QSUB_ARGS -cwd -o $LOGGING/\$TASK_ID.out -e $LOGGING/\$TASK_ID.err $var_args -N batch_3d -t 1-$n_submit $BINDIR/$BUILD_SCRIPT
		job_id=$(qsub $QSUB_ARGS -cwd -o $LOGGING/\$TASK_ID.out -e $LOGGING/\$TASK_ID.err $var_args -N batch_3d -t 1-$n_submit $BINDIR/$BUILD_SCRIPT)
		echo $job_id

		wait_jobs_sge
	elif [ "$SUBMIT_MODE" = "TEST_LOCAL" ]; then
		export SLURM_ARRAY_TASK_ID=1
		export JOB_ID=test_local
		$BINDIR/$BUILD_SCRIPT
		exit
	elif [ "$SUBMIT_MODE" = "SLURM" ]; then
		echo     sbatch --export=$slurm_var_args $SBATCH_ARGS --parsable --signal=USR1@120 -o $LOGGING/%a.out -e $LOGGING/%a.err --array=1-$n_submit%500 -J batch_3d $BINDIR/$BUILD_SCRIPT
		job_id=$(sbatch --export=$slurm_var_args $SBATCH_ARGS --parsable --signal=USR1@120 -o $LOGGING/%a.out -e $LOGGING/%a.err --array=1-$n_submit%500 -J batch_3d $BINDIR/$BUILD_SCRIPT)
		log "submitted batch with job_id=$job_id"

		wait_jobs_slurm
	else
		echo "need to set a SUBMIT_MODE!"
		exit 1
	fi

done
