#!/bin/bash
# @Description: zippyshare.com file download script
# @URL: https://github.com/ffluegel/zippyshare
# @Usage: ./zippyshare.sh url

if [ -z "${1}" ]; then
    echo "usage: ${0} url"
    echo "batch usage: ${0} url-list.txt"
    echo "url-list.txt is a file that contains one zippyshare.com url per line"
    exit
fi

function zippydownload() {
    prefix="$(echo -n "${url}" | cut -c "11,12,31-38" | sed -e 's/[^a-zA-Z0-9]//g')"
    cookiefile="${prefix}-cookie.tmp"
    infofile="${prefix}-info.tmp"

    # loop that makes sure the script actually finds a filename
    filename=""
    retry=0
    while [ -z "${filename}" -a ${retry} -lt 10 ]; do
        let retry+=1
        rm -f "${cookiefile}" 2>/dev/null
        rm -f "${infofile}" 2>/dev/null
        curl -s -c "${cookiefile}" -o "${infofile}" -L "${url}"
        filename="$(cat "${infofile}" | grep "/d/" | cut -d'/' -f5 | cut -d'"' -f1 | grep -o "[^ ]\+\(\+[^ ]\+\)*")"
    done

    if [ "${retry}" -ge 10 ]; then
        echo "could not download file from ${url}"
        rm -f "${cookiefile}" 2>/dev/null
        rm -f "${infofile}" 2>/dev/null
        return 1
    fi

    # Get cookie
    if [ -f "${cookiefile}" ]; then
        jsessionid="$(cat "${cookiefile}" | grep "JSESSIONID" | cut -f7)"
    else
        echo "can't find cookie file for ${prefix}"
        exit 1
    fi

    if [ -f "${infofile}" ]; then
        # Get url algorithm
        dlbutton="$(grep -oE 'var a = [0-9]+' ${infofile} | grep -oE '[0-9]+')"
        if [ -n "${dlbutton}" ]; then
            algorithm="${dlbutton}/3+${dlbutton}"
            a="$(echo $((${algorithm})))"
        else
            dlbutton="$(grep 'getElementById..dlbutton...href' "${infofile}" | grep -oE '\([0-9].*\)')"
            if [ -n "${dlbutton}" ]; then
                algorithm="${dlbutton}"
                a="$(echo $((${algorithm})))"
            else
                echo "could not get zippyshare url algorithm"
                exit 1
            fi
        fi

        # Get ref, server, id
        ref="$(cat "${infofile}" | grep 'property="og:url"' | cut -d'"' -f4 | grep -o "[^ ]\+\(\+[^ ]\+\)*")"
        server="$(echo "${ref}" | cut -d'/' -f3)"
        id="$(echo "${ref}" | cut -d'/' -f5)"
    else
        echo "can't find info file for ${prefix}"
        exit 1
    fi

    # Build download url
    dl="https://${server}/d/${id}/${a}/${filename}"

    # Set browser agent
    agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"

    #Rename file output
    if [ -n "${outputName}" ]; then
        filename="${outputName}"
    else
         filename="download/${id}/${filename}"
         mkdir -p "download/${id}"
    fi

    echo "${filename}"

    # Start download file
    curl -# -A "${agent}" -e "${ref}" -H "Cookie: JSESSIONID=${jsessionid}" -C - "${dl}" -o "${filename}"; rm -f "${cookiefile}" 2>/dev/null;rm -f "${infofile}" 2>/dev/null
    #wget -c "${dl}" -O "${filename}"; rm -f "${cookiefile}" 2>/dev/null;rm -f "${infofile}" 2>/dev/null &
}

if [ -f "${1}" ]; then
    for url in $(cat "${1}" | grep -i 'zippyshare.com'); do
        zippydownload "${url}"
    done
else
    url="${1}"
    outputName="${2}"
    zippydownload "${url}" "${outputName}"
fi
