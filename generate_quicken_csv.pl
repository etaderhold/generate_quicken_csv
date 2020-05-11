#!/usr/bin/perl

use JSON::Parse 'json_file_to_perl';

my %ids = {};
my $output_dir = 'csv_out';
`mkdir $output_dir 2>&1`;

my $investments = json_file_to_perl("investments.json")->{'investments'};

foreach my $investment (@$investments) {
	my $type = $investment -> {'type'};
	if ($type eq 'ticker') {
		my $ticker = $investment -> {'ticker'};
		if ($ticker) {
			my $description = $investment -> {'description'};
			$description = $ticker unless $description;
			get_yahoo_csv($ticker, $description);
		}
		else {
			print "Type 'ticker' requires a ticker symbol. Skipping...\n";
		}
	} elsif ($type eq 'vanguard_trust') {
		my $id = $investment -> {'id'};
		if ($id =~ /^\d{4}$/) {
			my $description = $investment -> {'description'};
			$description = $id unless $description;
			get_vanguard_trust_csv($id, $description);
		}
		else {
			print "Type 'vanguard_trust' requires a four-digit ID. Skipping...\n";
		}

	}
}

sub get_vanguard_trust_csv {
	my $id = shift;
	my $description = shift;
	$description =~ s/\s//g;
	
	my $json_destination = "$output_dir/$id.json";
	my $csv_destination = "$output_dir/$description.csv";

	# Download JSON history for the fund from an undocumented Vanguard API.
	my $url = "https://api.vanguard.com/rs/ire/01/pe/fund/$id/price/price-history/.json?range=1Y";
	print "Downloading history for Vanguard fund ID $id...";
	`wget --referer=https://investor.vanguard.com/ --no-check-certificate $url -O $json_destination 2>&1`;
	print "Done\n";

	# Convert JSON to CSV
	print "Converting JSON for Vanguard fund ID $id to CSV...";
	my $description = $ids{$id};
	open CSV, '>', $csv_destination or die "Could not open file for writing.";
	print CSV "Date,Close,High,Low,Volume,Open\n";
	my $ref = json_file_to_perl($json_destination);

	my $prices = $ref->{'nav'}->[0]->{'item'};
	foreach my $item (@$prices) {
		my $date = substr $item->{'asOfDate'}, 0, 10;
		my $price = $item->{'price'};
		print CSV "$date,$price,0,0,0,0\n";
	}
	close CSV;
	`rm $json_destination`;
	print "...Done\n";
}

sub get_yahoo_csv {
	my $ticker = shift;
	my $description = shift;
	$description =~ s/\s//g;

	my $current_time = time();
	my $year_ago = $current_time - 60 * 60 * 24 * 366;

	my $url = "https://query1.finance.yahoo.com/v7/finance/download/$ticker?period1=$year_ago&period2=$current_time&interval=1d&events=history";
	print "$url\n";
	my $destination = "$output_dir/$description.csv";
	my $destination_tmp = "$destination.tmp";
	my $user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36";
	my $command = "wget -U \"$user_agent\" --no-check-certificate \"$url\" -O $destination";
	print "Downloading history for $ticker from Yahoo...";
	`$command 2>&1`;
	print "...done\n";

	# Yahoo will often return a row of "null" values for the current date. Quicken interprets these as zeroes. Strip these out.
	`grep -v null $destination > $destination_tmp`;
	`mv $destination_tmp $destination`;
}

