# Package Name
package MGDRelated::GType;

# Exported name
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(IfGenTypeMatch);

# 去除多余的碱基;
sub IfGenTypeMatch
{
	my ($MGType,$FGType) = @_;
	my $UnMatchFlag = 1;
	
	my @MBase = split //, $MGType;
	my @FBase = split //, $FGType;
	my %MB = ();
	for my $i (0 .. $#MBase)
	{
		$MB{$MBase[$i]} = 1;
	}
	for my $i (0 .. $#FBase)
	{
		if($MB{$FBase[$i]})
		{
			$UnMatchFlag = 0;
			last;
		}
	}
	my $MatchFlag = 1;
	$MatchFlag = 0 if($UnMatchFlag);
	
	return $MatchFlag;
}

1;