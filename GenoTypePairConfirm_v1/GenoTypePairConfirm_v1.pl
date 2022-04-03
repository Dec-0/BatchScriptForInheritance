#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;
use MGDRelated::GType;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my ($File4MVar,$File4FVar,$File4GTypePair,$File4FDepthInfo,$Dir,$MinDepth);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script can be used to confirm the genotype of maternal-fetal pair from the variants calling result.
  
  本脚本用于确定母子配对样本的组合基因型列表。
  
  该版本以母本列表为基础逐个变异检查，假如母本中有检出、子代深度不低于10且母子基因型组成合理的，才会输出。
 
 -m      ( Required ) Variants calling result of maternal cfDNA;
                      母本变异检测结果。
 -f      ( Required ) Variants calling result of fetal cfDNA;
                      子代变异检测结果。
 -o      ( Required ) File for result logging;

 -d      ( Optional ) Depth info for fetal variants;
 -bin    ( Optional ) List for searching of related bin or scripts; 
 -h      ( Optional ) Help infomation;

USAGE

GetOptions(
	'm=s' => \$File4MVar,
	'f=s' => \$File4FVar,
	'o=s' => \$File4GTypePair,
	'd:s' => \$File4FDepthInfo,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !$File4MVar || !$File4FVar)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	IfFileExist($File4MVar,$File4FVar);
	IfFileExist($File4FDepthInfo) if($File4FDepthInfo);
	$Dir = dirname $File4GTypePair;
	$Dir = IfDirExist($Dir);
	
	$BinList = BinListGet() if(!$BinList);
	$MinDepth = BinSearch("MinDepth",$BinList,1);
}

if(1)
{
	# 逐行处理Maternal位点（chr,pos,,ref,alt,freq,fulldepth）;
	open(MVAR,"cat $File4MVar | grep -v ^# | cut -f 1-7 |") unless($File4MVar =~ /\.gz$/);
	open(MVAR,"zcat $File4MVar | grep -v ^# | cut -f 1-7 |") if($File4MVar =~ /\.gz$/);
	open(GP,"> $File4GTypePair") unless($File4MVar =~ /\.gz$/);
	open(GP,"| gzip > $File4GTypePair") if($File4MVar =~ /\.gz$/);
	print GP join("\t","#Chr","Start","End","Ref","Alt","MaternalGType","MaternalFreq","MaternalDepth","FetalGType","FetalFreq","FetalDepth"),"\n";
	while(my $Line = <MVAR>)
	{
		chomp $Line;
		my ($Chr,$From,$To,$Ref,$Alt,$Freq,$Depth) = split /\t/, $Line;
		if($Depth < $MinDepth)
		{
			print "[ Info ] Maternal depth fail in $Line\n";
			next;
		}
		
		# Maternal GenoType;
		my $MGType = "AB";
		$MGType = "BB" if($Freq < 0.25);
		$MGType = "AA" if($Freq > 0.75);
		
		# Fetal GenoType;
		# 默认没有检出就是纯合;
		my ($FGType,$FFreq,$FDepth) = ("BB","-","-");
		my $Return = "";
		$Return = `cat $File4FVar | awk '{if(\$1 == "$Chr" && \$2 == "$From" && \$4 == "$Ref" && \$5 == "$Alt"){print \$0}}' | cut -f 6,7` unless($File4FVar =~ /\.gz$/);
		chomp $Return;
		($FFreq,$FDepth) = split /\t/, $Return if($Return);
		# 假如没有检测结果则确定深度是否合理;
		if($FDepth eq "-" && $File4FDepthInfo)
		{
			$FDepth = `cat $File4FDepthInfo | grep ^'$Chr'\$'\\t''$From'\$'\\t' | head -n1 | cut -f 3` unless($File4FDepthInfo =~ /\.gz$/);
			$FDepth = `zcat $File4FDepthInfo | grep ^'$Chr'\$'\\t''$From'\$'\\t' | head -n1 | cut -f 3` if($File4FDepthInfo =~ /\.gz$/);
			chomp $FDepth;
			$FDepth = 0 unless($FDepth);
		}
		if($FFreq ne "-")
		{
			$FGType = "AB" if($FFreq >= 0.25 && $FFreq <= 0.75);
			$FGType = "AA" if($FFreq > 0.75);
		}
		if($FDepth ne "-" && $FDepth < $MinDepth)
		{
			print "[ Info ] Fetal depth ($FDepth) fail in $Chr $From $To\n";
			next;
		}
		
		# 确定基因型组合是否合理;
		unless(&IfGenTypeMatch($MGType,$FGType))
		{
			print "[ Warning ] Gene type pair confuse in $Chr $From $To $Ref $Alt ($MGType vs. $FGType)\n";
			next;
		}
		
		print GP join("\t",$Chr,$From,$To,$Ref,$Alt,$MGType,$Freq,$Depth,$FGType,$FFreq,$FDepth),"\n";
	}
	close MVAR;
	close GP;
}
printf "[ %s ] The end.\n",TimeString(time,$BeginTime);


######### Sub functions ##########
