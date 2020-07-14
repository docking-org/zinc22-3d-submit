#!/bin/bash
# req: ZINC_PORT
# req: EXPORT_DEST

for partition in /local2/load/*; do

    if [ -f $partition/config.txt ]; then

        PORT=`cat $partition/config.txt`

        if [ "$PORT" = "$ZINC_PORT" ]; then

            echo "found files for database on port $ZINC_PORT, preparing files..."

            PARTITION_NAME=`basename $partition`
            EXPORT_FILE=$EXPORT_DEST/${PARTITION_NAME}.smi
            EXPORT_TMP_FILE=$EXPORT_FILE.tmp
            
            for tranche in $partition/src/*; do

                echo $tranche

                TRANCHE_NAME=`basename $tranche`
                SUBSTANCE_FILE=$tranche/substance.txt
                cat $SUBSTANCE_FILE | awk -v t=$TRANCHE_NAME '{print $1 " " t " " $3}' >> $EXPORT_TMP_FILE
            
            done

            echo "exporting zinc ids..." 

            python export_zinc_ids.py $EXPORT_TMP_FILE > $EXPORT_FILE
            rm $EXPORT_TMP_FILE

            echo "done!"
        
        fi
    
    fi

done