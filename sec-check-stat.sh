#!/bin/bash
# This script computes statistic for security features
# activeted in medkit or package elf files

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DIR_DATA=""

calc_percent()
{
	local a c tmp ret

	a="$1"
	c="$2"
	tmp=$(echo "$a/($c/100.0)" |bc -l|sed "s/\./,/")
	printf "%.*f\n" 2 $tmp
}

create_stat() {
	local log_file data_dir
	log_file=sec_log.txt
	data_dir="$1"

	rm $log_file

	for i in $(find $data_dir/ -type f)
	do
		file $i|grep "ELF">/dev/null
		if [ "$?" -eq "0" ]; then
			./checksec --file=$i|tail -n1>>$log_file
		fi
	done

	# Remove stat for none ELF files
	cat $log_file|grep -v "Not an ELF file">a
	mv a $log_file
	rm -rf $data_dir
}

unpack_arch()
{
	pkg="$1"
	pkg_name=$(basename "$pkg")
	arch_type="$2"
	tmp_dir=$(mktemp --suffix=.checksec -d)
	cp $pkg $tmp_dir/
	cd $tmp_dir

	tar xf $pkg_name
	if [ "$arch_type" == "ipk" ]; then
		tar xf data.tar.gz
	fi
	DIR_DATA=$tmp_dir
	cd $DIR
}

print_stat()
{
	local log_file
	log_file="$1"

	count=$(cat $log_file|wc -l)

	canary=$(cat $log_file|grep -v "No canary found"|wc -l)
	pie=$(cat $log_file|grep -v "No PIE"|wc -l)
	relro=$(cat $log_file|grep "Full RELRO"|wc -l)
	nx=$(cat $log_file|grep "NX enabled"|wc -l)
	fortify=$(cat $log_file|grep "Yes"|wc -l)

	canary_p=$(calc_percent $canary $count)
	pie_p=$(calc_percent $pie $count)
	relro_p=$(calc_percent $relro $count)
	nx_p=$(calc_percent $nx $count)
	fortify_p=$(calc_percent $fortify $count)

	printf "	count	percent\n"
	printf "______________________\n"
	printf "canary	$canary	$canary_p\n"
	printf "pie	$pie	$pie_p\n"
	printf "relro	$relro	$relro_p\n"
	printf "nx	$nx	$nx_p\n"
	printf "fortify	$fortify	$fortify_p\n"
	printf "\n"
	printf "Item_count=$count\n"
}


###################################

cmd=$1
case $cmd in
	-p)
		# Package
		if [ ! -f "$2" ]; then
			echo "No arch file !"
			exit
		fi
		unpack_arch "$2" ipk
		create_stat "$DIR_DATA"
		print_stat sec_log.txt
	;;
	-m)
		# Medkit
		if [ ! -f "$2" ]; then
			echo "No arch file !"
			exit
		fi
		unpack_arch "$2" medkit
		create_stat "$DIR_DATA"
		print_stat sec_log.txt

	;;
	help|*)
		printf "Help:\n"
		printf "\-p	Unpack package\n"
		printf "\-m	Unpack medkit\n"
	;;
esac
