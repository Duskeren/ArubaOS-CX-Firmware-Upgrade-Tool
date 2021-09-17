#!/bin/bash

#Defaults:
USERNAME="admin"
PASSWORD="pass"
FIRMWAREFILE=""
BOOTBANK="secondary"
SWITCH="127.0.0.1"
APIVERSION="v10.04"
REBOOT="FALSE"
YESTOALL="FALSE"
COOKIEFILE="cookie_$(openssl rand -hex 4).txt"

if [ "$1" == "" ] ;then
  echo "Example: ./cx_upgrade.sh -f ArubaOS-CX_6100_10_08_0001.swi -s switch01.local --bootbank primary --reboot -y"
  echo "-u | --username		Username"
  echo "-p | --password		Password"
  echo "-f | --firmwarefile	Firmware file"
  echo "-b | --bootbank		Firmware boot bank, primary/secondary"
  echo "-s | --switch		Switch to connect to"
  echo "-a | --apiversion	API version endpoint"
  echo "-r | --reboot		Reboot to firmware after upload"
  echo "-y | --yes		Yes to all questions"
  exit 0
fi

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -u|--username)
      USERNAME="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--password)
      PASSWORD="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--firmwarefile)
      FIRMWAREFILE="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--bootbank)
      BOOTBANK="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--switch)
      SWITCH="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--apiversion)
      APIVERSION="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--reboot)
      REBOOT=TRUE
      shift # past argument
      ;;
    -y|--yes)
      YESTOALL=TRUE
      shift # past argument
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

echo "Arguments received:"
echo "Username = ${USERNAME}"
echo "Password = ${PASSWORD}"
echo "Firmware = ${FIRMWAREFILE}"
echo "Boot Bank = ${BOOTBANK}"
echo "Switch = ${SWITCH}"
echo "API version = ${APIVERSION}"
echo "Yes To All = ${YESTOALL}"
echo "Reboot = ${REBOOT}"
echo "Cookiefile = ${COOKIEFILE}"
echo ""

if [ "$YESTOALL" != "TRUE" ] ;then
echo -n "Continue (y/n)? "
read continue
if [ "$continue" == "${continue#[Yy]}" ] ;then
    exit 0
fi
echo ""
fi

echo "Getting ready!"
rm -f ${COOKIEFILE}
echo -n "Logging in... "
status_code=$(curl --write-out '%{http_code}' --location --request POST 'https://'${SWITCH}'/rest/'${APIVERSION}'/login?username='${USERNAME}'&password='${PASSWORD}'' -k --silent --output /dev/null --cookie-jar ${COOKIEFILE})
if [[ "$status_code" -ne 200 ]] ; then
  echo ""
  echo "Login failed!"
  exit 1
fi
echo "OK!"
echo ""
echo "Current firmware status:"
curl --location --request GET 'https://'${SWITCH}'/rest/'${APIVERSION}'/firmware' -k --silent --cookie ${COOKIEFILE} | sed -e 's/[{"}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed -e 's/:/ = /g'
echo ""

if [ "$YESTOALL" != "TRUE" ] ;then
echo -n "Continue (y/n)? "
read continue
if [ "$continue" == "${continue#[Yy]}" ] ;then
    exit 0
fi
echo ""
fi


if [ "$FIRMWAREFILE" != "" ] ;then
  echo "Uploading firmware:"
  status_code=$(curl --write-out '%{http_code}' --location --request POST 'https://'${SWITCH}'/rest/'${APIVERSION}'/firmware?image='${BOOTBANK}'' --header 'Content-Type: multipart/form-data' -F 'fileupload=@'${FIRMWAREFILE}'' --progress-bar -k --output /dev/null --cookie ${COOKIEFILE})
  if [[ "$status_code" -ne 200 ]] ; then
    echo "Upload failed!"
    exit 1
  fi
  echo "OK!"
  echo ""
  echo "New firmware status:"
  curl --location --request GET 'https://'${SWITCH}'/rest/'${APIVERSION}'/firmware' -k --silent --cookie ${COOKIEFILE} | sed -e 's/[{"}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed -e 's/:/ = /g'
  echo ""
else
  echo "No firmware file specified, skipping upload"
fi


if [ "$REBOOT" == "TRUE" ] ;then
  if [ "$YESTOALL" != "TRUE" ] ;then
    echo -n "Reboot (y/n)? "
    read continue
    if [ "$continue" == "${continue#[Yy]}" ] ;then
      echo "Rebooting..."
      curl --location --request POST 'https://'${SWITCH}'/rest/'${APIVERSION}'/boot?image='${BOOTBANK}'' -k --silent --cookie ${COOKIEFILE} --output /dev/null
      rm -f ${COOKIEFILE}
      echo "All done!"
      exit 0
    fi
  else
    echo "Rebooting..."
    curl --location --request POST 'https://'${SWITCH}'/rest/'${APIVERSION}'/boot?image='${BOOTBANK}'' -k --silent --cookie ${COOKIEFILE} --output /dev/null
    rm -f ${COOKIEFILE}
    echo "All done!"
    exit 0 
  fi
fi

curl --location --request POST 'https://'${SWITCH}'/rest/'${APIVERSION}'/logout' -k --silent --output /dev/null
rm -f ${COOKIEFILE}
echo "All done!"
exit 0