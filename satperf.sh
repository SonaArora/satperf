#Author Pradeep Kumar Surisetty<psuriset@redhat.com>
#!/bin/bash
source satperf.cfg
config=$2
testname=satelitte61-$config

function satperf_usage() {
                printf "The following options are available:\n"
                printf "\n"
}

function log()
{
    echo "[$(date)]: $*"
}

function pbench_config()
{
 log clearing preregistered tools
 echo 3 > /proc/sys/vm/drop_caches
 #clear preconfigured tools, if any
 if $PBENCH ; then
   kill-tools
   clear-results
   clear-tools
   log registering tools
   register-tool-set
 fi
}

function pbench_postprocess()
{
  log clearing tools
  kill-tools
  clear-tools
  move-results
}

function upload_manifest()
{
  log Upload Manifest
  hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" subscription upload --organization "${ORG}" --file $MANIFSET --repository-url $REPOSERVER
}

function create_life_cycle_env()
{
   log create life cyccle environment
   time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" lifecycle-environment create --name='DEV' --prior='Library' --organization="${ORG}"
   time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" lifecycle-environment create --name='QE' --prior='DEV' --organization="${ORG}"
}

function enable_content()
{
   log Enable content
   time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 5 Server (RPMs)" --basearch="x86_64" --releasever="5Server" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 5 Server (RPMs)" --basearch="i386" --releasever="5Server" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

#kickstart
#  time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 5 Server (Kickstart)" --basearch="x86_64" --releasever="${RHEL5}" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"
#  time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 6 Server (Kickstart)" --basearch="x86_64" --releasever="${RHEL6}" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

  time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 6 Server (RPMs)" --basearch="x86_64" --releasever="6Server" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 6 Server (RPMs)" --basearch="i386" --releasever="6Server" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

#  time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 7 Server (Kickstart)" --basearch="x86_64" --releasever="${RHEL7}" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"

  time hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository-set enable --name="Red Hat Enterprise Linux 7 Server (RPMs)" --basearch="x86_64" --releasever="7Server" --product "Red Hat Enterprise Linux Server" --organization "${ORG}"
}

function sync_content()
{
# for org in $(hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" --csv repository list --organization="${ORG}" --per-page=1000 | cut -d ',' -f 1 | grep -vi '^ID')
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 1 --organization="${ORG}"  2>&1
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 2 --organization="${ORG}"  2>&1
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 3 --organization="${ORG}"  2>&1
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 4 --organization="${ORG}"  2>&1
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 5 --organization="${ORG}"  2>&1
 hammer -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" repository synchronize --id 6 --organization="${ORG}"  2>&1
}

function sync_enable_bg()
{
user-benchmark  --config=$tname-sync  -- "./scripts/sync-repos.sh"
}

function content_view_create()
{
user-benchmark --config=$tname-cv-create -- "./scripts/cv_create.sh"
}

function content_view_publish()
{
chmod 0644 cv_publish.sh
user-benchmark --tool-group=sat6 --config=$tname-cv-publish -- "./scripts/cv_publish.sh"
}

function content_view_promote()
{
chmod 0644 cv_promote.sh
user-benchmark  --config=$tname-cv-promote -- "./scripts/cv_promote.sh"
}

function sync_content_bg()
{
user-benchmark  --config=$tname -- "./scripts/sync_content.sh"
}

function enable_content_bg()
{
user-benchmark  --config=$tname-cv-promote -- "./scripts/enable_content_bg.sh"
}

function install_capsule()
{
OS_MAJOR_VERSION=`sed -rn 's/.*([0-9])\.[0-9].*/\1/p' /etc/redhat-release`
HOSTNSAME=`hostname`
rm -rf scripts/capsule.repo
echo "[CAPSULE REPO]" >> scripts/capsule.repo
echo "baseurl=$SAT_REPO/latest-stable-Satellite-$SAT_VERSION-RHEL-$OS_MAJOR_VERSION/compose/Capsule/x86_64/os/" >> scripts/capsule.repo
echo "enabled=1" >> scripts/capsule.repo
echo "gpgcheck=0" >> scripts/capsule.repo

pulp_oauth_secret=$(awk '{print $2}' /var/lib/puppet/foreman_cache_data/katello_oauth_secret)
foreman_oauth_secret=$(awk '{print $2}' /var/lib/puppet/foreman_cache_data/oauth_consumer_secret)
foreman_oauth_key=$(awk '{print $2}' /var/lib/puppet/foreman_cache_data/oauth_consumer_key)

for  capsule in $CAPSULES; do

echo 'subscription-manager register --username='$RHN_USERNAME' --password='RHN_PASSWORD' --force' >> scripts/capsule_install_$capsule.sh
echo 'subscription-manager attach --pool='$pool_id'' >> scripts/capsule_install_$capsule.sh
cat scripts/capsule_install.sh >> scripts/capsule_install_$capsule.sh
echo 'subscription-manager register --org "Default_Organization"  --username '$ADMIN_USER' --password '$ADMIN_PASSWORD' --force' >> scripts/capsule_install_$capsule.sh
echo 'rpm -Uvh http://'$HOSTNAME'/pub/katello-ca-consumer-latest.noarch.rpm' >> scripts/capsule_install_$capsule.sh
echo  'capsule-installer --parent-fqdn          "'$HOSTNAME'"\
                    --register-in-foreman  "true"\
                    --foreman-oauth-key    "'$foreman_oauth_key'"\
                    --foreman-oauth-secret "'$foreman_oauth_secret'"\
                    --pulp-oauth-secret    "'$pulp_oauth_secret'"\
                    --certs-tar            "/root/'"$capsule"'-certs.tar"\
                    --puppet               "true"\
                    --puppetca             "true"\
                    --pulp                 "true"' >>  scripts/capsule_install_$capsule.sh

#clear old certs if any 
if [ -f ~/$capsule-certs.tar ]; then
	rm -rf ~/$capsule-certs.tar
fi
capsule-certs-generate --capsule-fqdn $capsule --certs-tar $capsule-certs.tar

scp -o "${SSH_OPTS}" ~/$capsule-certs.tar root@$capsule:.
scp -o "${SSH_OPTS}" scripts/capsule.repo root@$capsule:/etc/yum.repos.d/
scp -o "${SSH_OPTS}" scripts/requirements-capsule.txt root@$capsule:.
scp -o "${SSH_OPTS}" scripts/capsule_install_$capsule.sh root@$capsule:.
ssh -o "${SSH_OPTS}" root@$capsule "chmod 0644 capsule_install_$capsule.sh;  ./capsule_install_$capsule.sh"

rm -rf scripts/capsule_install_$capsule.sh
done
}

function remove_capsule()
{
for  capsule in $CAPSULES; do
  scp scripts/capsule-remove root@$capsule:/usr/sbin/
  ssh root@$capsule "rm -rf /home/backup/ ;  capsule-remove"
done
}

function sat_backup()
{
 rm -rf /home/backup
 katello-backup /home/backup
}

function restore_backup()
{
 katello-restore /home/backup/
}
function install()
{
python install_satelite.py
}

opts=$(getopt -q -o jic:t:b:sd:r: --longoptions "help,install,sat-backup,sat-restore,setup,upload,create-life-cycle,enable-content,sync-content,install-capsule,remove-capsule,all" -n "getopt.sh" -- "$@");

eval set -- "$opts";
while true; do
	case "$1" in
        	--help)
                satperf_usage
                exit
                ;;
		--install)
		echo "install"
		python install_satelitte.py
		#install
		shift
		;;
		--sat-backup)
		sat_backup
		shift
		;;	
                --sat-restore)
		restore_backup
		shift
		;;
                --setup)       
		pbench_config			
		shift
		;;
  	        --upload)
		upload_manifest
		shift
		;;
	        --create-life-cycle)
		create_life_cycle_env
		shift
		;;
	        --enable-content)
		enable_content
		shift
		;;
                --sync-content)
		sync_content
		shift
		;;
	        --install-capsule)
		install_capsule
		shift
		;;
	        --remove-capsule)
		remove_capsule
		shift
		;;
	        --all)
		python install_satelite.py
                sat_backup
		upload_manifest
		enable_content
		sleep 10
		sync_content
		install_capsule
		sync_capsule
                shift
		;;
            	--)
               	shift
               	break
               	;;
	esac
done
