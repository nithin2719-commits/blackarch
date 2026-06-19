#!/usr/bin/env bash
# Curated "quick start" recipes for the tools people actually reach for.
#
# --help is complete but overwhelming; these are the 2-4 commands that get you
# moving. Keyed by binary name. Each entry is: one line per example, in the
# form  cmd<TAB>what it does.  $T stands for "the target you type in".
#
# Anything not listed here falls back to the tool's own --help, so coverage of
# all 4000+ tools is never worse than before — this only makes the common ones
# friendlier.

ba_examples() {
    case "$1" in
    nmap) cat <<'EOF'
nmap -sV -sC TARGET	version + default scripts (the everyday scan)
nmap -p- --min-rate 5000 TARGET	all 65535 ports, fast
nmap -sn 192.168.1.0/24	ping-sweep a subnet, no port scan
nmap -A -T4 TARGET	aggressive: OS, version, scripts, traceroute
EOF
;;
    nikto) cat <<'EOF'
nikto -h http://TARGET	scan a web server for known issues
nikto -h TARGET -ssl	force HTTPS
nikto -h TARGET -o report.html -Format html	save an HTML report
EOF
;;
    gobuster) cat <<'EOF'
gobuster dir -u http://TARGET -w /usr/share/wordlists/dirb/common.txt	find hidden dirs
gobuster dns -d TARGET -w /usr/share/wordlists/subdomains.txt	subdomain brute
gobuster vhost -u http://TARGET -w list.txt	virtual-host discovery
EOF
;;
    feroxbuster) cat <<'EOF'
feroxbuster -u http://TARGET	recursive content discovery
feroxbuster -u http://TARGET -x php,txt,html	try these extensions
feroxbuster -u http://TARGET -w wordlist.txt -t 50	custom list, 50 threads
EOF
;;
    ffuf) cat <<'EOF'
ffuf -u http://TARGET/FUZZ -w wordlist.txt	dir/file fuzzing (FUZZ = marker)
ffuf -u http://TARGET -H 'Host: FUZZ.target' -w subs.txt	vhost fuzz
ffuf -u 'http://TARGET/?id=FUZZ' -w ids.txt -mc 200	param fuzz, match 200s
EOF
;;
    sqlmap) cat <<'EOF'
sqlmap -u 'http://TARGET/?id=1' --batch	auto-detect SQLi (no prompts)
sqlmap -u URL --dbs	list databases
sqlmap -u URL -D dbname --tables	list tables in a db
sqlmap -r request.txt --dump	replay a saved request and dump data
EOF
;;
    hydra) cat <<'EOF'
hydra -l admin -P rockyou.txt TARGET ssh	brute one user over SSH
hydra -L users.txt -P pass.txt TARGET ftp	user+pass lists over FTP
hydra -l admin -P pass.txt TARGET http-post-form '/login:user=^USER^&pass=^PASS^:Invalid'	web form
EOF
;;
    hashcat) cat <<'EOF'
hashcat -m 0 hashes.txt rockyou.txt	crack MD5 with a wordlist
hashcat -m 1000 hashes.txt rockyou.txt -r rules/best64.rule	NTLM + rules
hashcat --identify hashes.txt	guess the hash mode (-m) to use
EOF
;;
    john) cat <<'EOF'
john --wordlist=rockyou.txt hashes.txt	wordlist crack
john --show hashes.txt	show already-cracked passwords
zip2john file.zip > hash.txt	extract a crackable hash from a zip
EOF
;;
    wireshark) cat <<'EOF'
wireshark	opens the GUI — pick an interface to start capturing
tshark -i wlan0 -w cap.pcapng	headless capture to a file
EOF
;;
    tcpdump) cat <<'EOF'
tcpdump -i any -n	watch all traffic, no name resolution
tcpdump -i eth0 -w cap.pcap	write to a pcap for later
tcpdump -i any port 80 -A	HTTP only, print payloads as text
EOF
;;
    hashid) cat <<'EOF'
hashid 'HASH'	identify a hash type
hashid -m 'HASH'	also show the hashcat -m mode
EOF
;;
    wpscan) cat <<'EOF'
wpscan --url http://TARGET	enumerate a WordPress site
wpscan --url TARGET -e u	enumerate usernames
wpscan --url TARGET -e vp --api-token TOKEN	vulnerable plugins
EOF
;;
    whatweb) cat <<'EOF'
whatweb TARGET	fingerprint the tech stack
whatweb -a 3 TARGET	aggressive fingerprint
EOF
;;
    dirb) cat <<'EOF'
dirb http://TARGET	default wordlist dir scan
dirb http://TARGET wordlist.txt -X .php,.bak	specific extensions
EOF
;;
    msfconsole) cat <<'EOF'
msfconsole -q	start quietly
search TYPE:exploit NAME	(inside msf) find a module
use path/to/module	select it, then `show options`
EOF
;;
    *) return 1 ;;
    esac
}
