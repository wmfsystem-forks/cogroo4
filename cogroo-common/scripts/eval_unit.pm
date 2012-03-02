#!/usr/bin/perl

package eval_unit;

use Time::HiRes;
use Data::Dumper;
use strict 'vars';
use File::Temp qw/ tempfile tempdir /;

use constant CORPUS_ROOT => $ENV{'CORPUS_ROOT'};

if ( CORPUS_ROOT eq '' ) {
	die "Env var CORPUS_ROOT undefined";
}

use constant {
	CF   => CORPUS_ROOT . "/Bosque/Bosque_CF_8.0.ad.txt",
	CP   => CORPUS_ROOT . "/Bosque_CP_8.0.ad.txt",
	CFCP => CORPUS_ROOT . "/Bosque_CFCP_8.0.ad.txt",
	VCF  => CORPUS_ROOT . "/FlorestaVirgem/FlorestaVirgem_CF_3.0_ad.txt",
	AMA  => CORPUS_ROOT . "/amazonia.ad",
	LIT  => CORPUS_ROOT . "/selva_lit.ad",
	CIE  => CORPUS_ROOT . "/selva_cie.ad",

	ENCODING   => "ISO-8859-1",
	MOD_PREFIX => "model/pt-",
	MOD_SUFIX  => ".bin"
};

my %opt;
my %extraOpt;

my $fhLog;

sub printToLog {
	my $info = shift;
	print $info;
	if($fhLog) {
		print $fhLog $info;
	}
}

sub createParams {
	( my $pfh ) = @_;

	my $threads = $opt{p};
	$threads = 8 if ( $threads eq '' );

	my $algorithm = $opt{a};
	$algorithm = "MAXENT" if ( $algorithm eq '' );

	my $cutoff = $opt{c};
	$cutoff = 5 if ( $cutoff eq '' );

	my $params = "Threads=$threads
Iterations=100
Algorithm=$algorithm
Cutoff=$cutoff";
	printToLog( "Creating params: \n$params\n\n");
	print $pfh $params;
}

my %simpleF = ( sent => 1, tok => 1, con => 1, prop => 1 );
my %simpleA = ( pos => 1 );

sub filter {
	my %out;
	my @res     = @_;
	my $capture = 0;
	if ( $simpleF{ $opt{t} } ) {
		foreach (@res) {
			if ( !$capture ) {
				$capture = 1 if $_ =~ m/^Precision.*/;
			}
			if ($capture) {
				$_ =~ m/^([^:]+):\s+([\d\.\,]+)/;
				$out{$1} = $2;
			}
		}
	} elsif( $simpleA{$opt{t}}) {
		foreach (@res) {
			if ( !$capture ) {
				$capture = 1 if $_ =~ m/^Accuracy.*/;
			}
			if ($capture) {
				$_ =~ m/^([^:]+):\s+([\d\.\,]+)/;
				$out{$1} = $2;
			}
		}
	}
	else {
		die "don't know which filter to use for: -t $opt{t}";
	}
	return %out;
}

sub checkError {
	my $err = 0;
	my @res     = @_;
	foreach my $line (@res) {
		if($line =~ m/\[ERROR\] For more information about the errors/) {
			$err = 1;
		}
	}
	
	if($err) {
		my $log = "=== Failed to execute command ===\n\n";
		$log .= join "\t", @res;
		printToLog $log . "\n\n";
		
		die "Failed to execute command";
	}
	#[ERROR] For more information about the errors
}

sub getNumberOfPreds {
	my %out;
	my @res     = @_;
	my $capture = 0;
	my $preds;
		foreach (@res) {
			if ( $_ =~ m/^\s+Number of Predicates:\s+([\d\.\,]+)/ ) {
				$preds = $1;
			}
		}
	
	return $preds;
}

sub get_temp_filename {
	my $fh = File::Temp->new( SUFFIX => '.module', );
	my $filename = $fh->filename;
	chmod 0660, $filename;
	return $filename;
}

sub executeCV {
	my $command = shift;
	if ( $opt{e} ) {
		printToLog "Will execute command: $command\n";

		my $start_time = [ Time::HiRes::gettimeofday() ];
		my @res        = `sh $command 2>&1`;
		my $diff       = Time::HiRes::tv_interval($start_time);

		checkError(@res);

		my %results = filter(@res);

		$results{"eval_time"} = $diff;

		return %results;
	}
}

sub executeTr {
	my $command = shift;
	my $out     = "# results for $command\n";
	printToLog "Will execute command: $command\n";

	my $start_time = [ Time::HiRes::gettimeofday() ];
	my @res        = `sh $command 2>&1`;
	my $diff       = Time::HiRes::tv_interval($start_time);

	print @res;
	checkError(@res);
	my %results;
	$results{"tr_time"} = $diff;
	$results{"predicates"} = getNumberOfPreds(@res);

	return %results;
}


sub exec() {
	%opt = %{$_[0]};
	%extraOpt = %{$_[1]};
	$fhLog = $_[2];

	# Create the params file
	my ( $paramsFileHandler, $paramsFileName ) = tempfile();
	createParams($paramsFileHandler);
	
	# Create model file name
	my $model = '';
	if ( $opt{f} ) {
		$model = MOD_PREFIX . $opt{t} . MOD_SUFIX;
	}
	else {
		$model = get_temp_filename();
	}
	
	# create corpus args
	my $data = $opt{d}->();
	die "The parameter -d corpus name is mandatory." if $data eq '';
	
	my $extraOption = '';
	if ( $opt{o} ne "" ) {
		my @tokens = split( /,/, $opt{o} );
		foreach my $token (@tokens) {
			$extraOption .= $extraOpt{$token} . ' ';
		}
	}
	my $basicCommand = " -params $paramsFileName -lang pt -encoding ";
	my $trCommand = '';
	my $cvCommand = '';
	
	if ( $opt{t} eq 'sent' ) {
		$trCommand .=
		    "scripts/opennlp SentenceDetectorTrainer.ad $basicCommand "
		  . ENCODING
		  . " -data $data -model $model $extraOption";
		$cvCommand .=
		    "scripts/opennlp SentenceDetectorCrossValidator.ad $basicCommand "
		  . ENCODING
		  . " -data $data $extraOption";
	}
	
	if ( $opt{t} eq 'tok' ) {
		$trCommand .=
		    "scripts/opennlp TokenizerTrainer.ad "
		  . "-detokenizer ../../opennlp/opennlp-tools/lang/pt/tokenizer/pt-detokenizer.xml "
		  . "$basicCommand "
		  . ENCODING
		  . " -data $data -model $model $extraOption";
		$cvCommand .=
		    "scripts/opennlp TokenizerCrossValidator.ad "
		  . "-detokenizer ../../opennlp/opennlp-tools/lang/pt/tokenizer/pt-detokenizer.xml "
		  . "$basicCommand "
		  . ENCODING 
		  . " -data $data $extraOption";
	}
	
	
	
	if ( $opt{t} eq 'con' ) {
		$trCommand .=
		    "scripts/cogroo TokenNameFinderTrainer.ad "
		  . "$basicCommand "
		  . ENCODING
		  . " -data $data -model $model $extraOption";
		$cvCommand .=
		    "scripts/cogroo TokenNameFinderCrossValidator.adcon "
		  . "$basicCommand "
		  . ENCODING 
		  . " -data $data $extraOption";
	}
	
	if ( $opt{t} eq 'prop' ) {
		$trCommand .=
		    "scripts/cogroo TokenNameFinderTrainer.adexp "
		  . "$basicCommand "
		  . ENCODING
		  . " -tags prop -data $data -model $model $extraOption";
		$cvCommand .=
		    "scripts/cogroo TokenNameFinderCrossValidator.adexp "
		  . "$basicCommand "
		  . ENCODING 
		  . " -tags prop -data $data $extraOption";
	}
	
	if ( $opt{t} eq 'pos' ) {
		my $base = "$basicCommand "
		  . ENCODING
		  . " -data $data $extraOption";
		$trCommand .=
		    "scripts/opennlp POSTaggerTrainer.ad -model $model $base";
		$cvCommand .=
		    "scripts/opennlp POSTaggerCrossValidator.ad $base";
	}
	
	my %resCV = executeCV($cvCommand);
	
	my %resTr = executeTr($trCommand);
	my $modelSize = -s $model;
	$resTr{"model_size"} = $modelSize;
	
	my %res = ( %resCV, %resTr );
	
	#close the params file in the end of execution.
	close $paramsFileHandler;
	
	printToLog Dumper( \%res );

	return %res;
}
1;