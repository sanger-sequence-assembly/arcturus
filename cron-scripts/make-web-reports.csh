#!/bin/csh -f

echo
echo ------------------------------------------------------------
echo
echo Making Arcturus web reports at `date`

set ARCTURUS=/software/arcturus
set REPORTSCRIPT=${ARCTURUS}/utils/make-web-report
set WEBFOLDER=/nfs/WWWdev/INTWEB_docs/htdocs/Software/Arcturus/reports
set WEBPUBLISH=/software/bin/webpublish
set LOGFILE=reports.log

cd ${WEBFOLDER}

foreach ORG (`cat ~/active-organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Making report for $ORG

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG

  ${REPORTSCRIPT} -instance pathogen -organism $ORG > index.html

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
