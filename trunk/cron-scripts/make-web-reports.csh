#!/bin/csh -f

echo
echo ------------------------------------------------------------
echo
echo Making Arcturus web reports at `date` on `hostname`

if ( ! $?ARCTURUS_HOME ) then
    set ARCTURUS_HOME=/software/arcturus
endif

if ( ! $?WEBREPORTSCRIPT ) then
    set WEBREPORTSCRIPT=${ARCTURUS_HOME}/utils/make-web-report
endif

if ( ! $?WEBFOLDER ) then
    set WEBFOLDER=/nfs/WWWdev/INTWEB_docs/htdocs/Software/Arcturus/reports
endif

if ( ! $?WEBPUBLISH ) then
    set WEBPUBLISH=/software/bin/webpublish
endif

if ( ! $?ACTIVE_ORGANISMS_LIST ) then
    set ACTIVE_ORGANISMS_LIST=${HOME}/active-organisms.list
endif

if ( ! -f $ACTIVE_ORGANISMS_LIST ) then
    echo Cannot find active organisms list file $ACTIVE_ORGANISMS_LIST
    exit 1
endif

set LOGFILE=reports.log

cd ${WEBFOLDER}

foreach ORG (`cat ${ACTIVE_ORGANISMS_LIST}`)
  echo Making report for $ORG

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG

  ${WEBREPORTSCRIPT} -instance pathogen -organism $ORG > index.html

  popd
end

cd ..

echo Running webpublish at `date`

${WEBPUBLISH} -r reports

# And again, as suggested by Jody Clements (RT ticket #114188)

echo Re-running webpublsh at `date`

${WEBPUBLISH} -r reports

echo All done at `date`

exit 0