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

set LOGFILE=reports.log

cd ${WEBFOLDER}

foreach ORG (`cat ~/active-organisms.list | awk -F : '{print $1}' | uniq`)
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
