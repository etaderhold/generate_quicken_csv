#!/usr/bin/perl

use JSON::Parse 'json_file_to_perl';

my %ids = {};
my $output_dir = 'csv_out';
`mkdir $output_dir 2>&1`;

my $input_file = shift;
my $investments = json_file_to_perl($input_file)->{'investments'};

foreach my $investment (@$investments) {
	my $type = $investment -> {'type'};
	if ($type eq 'ticker') {
		my $ticker = $investment -> {'ticker'};
		if ($ticker) {
			my $description = $investment -> {'description'} || $ticker;
			get_yahoo_csv($ticker, $description);
		}
		else {
			print "Type 'ticker' requires a ticker symbol. Skipping...\n";
		}
	} elsif ($type eq 'vanguard_trust') {
		my $id = $investment -> {'id'};
		if ($id =~ /^\d{4}$/) {
			my $description = $investment -> {'description'} || $id;
			get_vanguard_trust_csv($id, $description);
		}
		else {
			print "Type 'vanguard_trust' requires a four-digit ID. Skipping...\n";
		}
	} elsif ($type eq 'vanguard_529') {
		my $id = $investment -> {'id'};
		if ($id =~ /^\d{4}$/) {
			my $description = $investment -> {'description'} || $id;
			get_vanguard_529_csv($id, $description);
		}
		else {
			print "Type 'vanguard_529' requires a four-digit ID. Skipping...\n";
		}
	} elsif ($type eq 'precious_metals') {
		my $metal = $investment -> {'metal'};
		if ($metal =~ /^[GSPL]$/) {
			my $description = $investment -> {'description'} || $metal;
			get_precious_metals_csv($metal, $description);
		}
		else {
			print "Type 'precious_metals' requires a one-character metal code. G = Gold, S = Silver, P = Platinum, L = Palladium). Skipping...\n";
		}
	} elsif ($type eq 'vanguard_daf') {
		my $id = $investment -> {'id'};
		my $description = $investment->{'description'} || $id;
		get_vanguard_daf_csv($id, $description);
	} else {
		print "Type $type not recognized. Skipping...\n";
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
	print "Downloading history for Vanguard trust fund $description...";
	`wget --referer=https://investor.vanguard.com/ --no-check-certificate $url -O $json_destination 2>&1`;
	print "done\n";

	# Convert JSON to CSV
	print "Converting JSON for Vanguard fund ID $id to CSV...";
	open $csv, '>', $csv_destination or die "Could not open file for writing.";
	print $csv "Date,Close,High,Low,Volume,Open\n";
	my $ref = json_file_to_perl($json_destination);

	my $prices = $ref->{'nav'}->[0]->{'item'};
	foreach my $item (@$prices) {
		my $date = substr $item->{'asOfDate'}, 0, 10;
		my $price = $item->{'price'};
		print $csv "$date,$price,0,0,0,0\n";
	}
	close $csv;
	`rm $json_destination`;
	print "...done\n";
}

sub get_vanguard_daf_csv {
	my $id = shift;
	my $description = shift;
	$description =~ s/\s//g;

	my $token_destination = "$output_dir/$id.token.json";
	my $history_json_destination = "$output_dir/$id.history.json";
	my $csv_destination = "$output_dir/$description.csv";

	print "Downloading history for Vanguard DAF fund $description...";
	# Get access token
	my $header = 'Authorization: Basic ZG9ub3JQb3J0YWxVSTpzZWNyZXQ=';
	my $post_data = 'grant_type=password&client_id=donorPortalUI&client_secret=secret&username=pwuser&password=Tomy%401234';
	my $token_url = 'https://www.vanguardcharitable.org/donor-portal/api/oauth/token';
	`wget --header='$header' --post-data='$post_data' $token_url -O $token_destination 2>&1`;
	my $token = json_file_to_perl($token_destination)->{'access_token'};
	print "auth token done...";

	# Get price history
	$header = "Authorization: Bearer $token";
	my $start_date = get_csv_date_string(time - 60 * 60 * 24 * 365);
	my $end_date = get_csv_date_string(time);
	my $history_url = "https://www.vanguardcharitable.org/donor-portal/api/investmentOptions/findHistoricalNAVByPoolIdsAndStartDateAndEndDate?firstPoolId=$id&secondPoolId=11&startDateStr=$start_date&endDateStr=$end_date&isIOD=true";
	`wget --header='$header' --no-check-certificate '$history_url' -O $history_json_destination 2>&1`;
	print "price history done.\n";

	print "Converting DAF history to CSV...";
	my $history = json_file_to_perl($history_json_destination)->{$id}->{'prices'};
	open $csv, '>', $csv_destination or die "Could not open file for writing.";
	print $csv "Date,Close,High,Low,Volume,Open\n";

	my $prices = $ref->{'nav'}->[0]->{'item'};
	foreach my $line (@$history) {
		my $date = get_csv_date_string($line->{'date'}/1000);
		my $price = $line->{'unitPrice'};
		print $csv "$date,$price,0,0,0,0\n";
	}
	close $csv;
	`rm $token_destination`;
	`rm $history_json_destination`;
	print "done\n";
}

sub get_yahoo_csv {
	my $ticker = shift;
	my $description = shift;
	$description =~ s/\s//g;

	my $current_time = time();
	my $year_ago = $current_time - 60 * 60 * 24 * 365;

	my $url = "https://query1.finance.yahoo.com/v7/finance/download/$ticker?period1=$year_ago&period2=$current_time&interval=1d&events=history";
	my $destination = "$output_dir/$description.csv";
	my $destination_tmp = "$destination.tmp";
	my $user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36";
	my $command = "wget -U \"$user_agent\" --no-check-certificate \"$url\" -O $destination";
	print "Downloading history for $ticker from Yahoo...";
	`$command 2>&1`;
	print "...done\n";

	# Yahoo will often return a row of "null" values for the current date. Quicken interprets these as zeroes. Strip these out.
	`grep -v null "$destination" > "$destination_tmp"`;
	`mv "$destination_tmp" "$destination"`;
}

sub get_vanguard_529_csv {
	my $id = shift;
	my $description = shift;
	$description =~ s/\s//g;

	my $html_destination = "$output_dir/$id.html";
	my $csv_destination = "$output_dir/$description.csv";

	# Download HTML price history from Vanguard
	my $current_time = time();
	my $year_ago = $current_time - 60 * 60 * 24 * 365;
	my $start = get_url_date_string($year_ago);
	my $end = get_url_date_string($current_time);

	my $url = "https://personal.vanguard.com/us/funds/tools/pricehistorysearch?radio=1&results=get&FundType=529Plans&FundIntExt=INT&FundId=$id&fundName=$id&radiobutton2=1&beginDate=$start&endDate=$end&year=#res";
	my $command = "wget --no-check-certificate \"$url\" -O $html_destination";
	print "Downloading history for Vanguard 529 fund $description...";
	`$command 2>&1`;
	print "...done\n";

	# Scrape HTML, output to CSV
	print "Converting HTML for $description to CSV...";
	open $csv, '>', $csv_destination or die "Could not open file for writing.";
	print $csv "Date,Close,High,Low,Volume,Open\n";
	open (my $html, $html_destination) or die "Could not open HTML!";
	while (<$html>) {
		if (/<td align="left">(.*)<\/td><td class="nr">\$(.*)<\/td>/) {
			my $date = $1;
			my $price = $2;
			print $csv "$date,$price,0,0,0,0\n";
		}
	}
	close $csv;

	`rm $html_destination`;
	print "...done\n";
}

sub get_precious_metals_csv {
	my $metal = shift;
	my $description = shift;

	my $json_destination = "$output_dir/$metal.json";
	my $csv_destination = "$output_dir/$description.csv";

	my $current_time = time();
	my $year_ago = $current_time - 60 * 60 * 24 * 365;
	my $start = get_url_date_string($year_ago);
	my $end = get_url_date_string($current_time);

	my $url = "https://www.amark.com/feeds/spothistory";
	my $postdata = "comCode=$metal&startDate=$start&endDate=$end&groupBy=day";

	print "Downloading precious metals history for $description...";
	`wget --no-check-certificate "$url" --post-data="$postdata" -O $json_destination 2>&1`;
	print "...done\n";

	# Convert JSON to CSV
	print "Converting JSON for precious metal $description to CSV...";
	open $csv, '>', $csv_destination or die "Could not open file for writing.";
	print $csv "Date,Close,High,Low,Volume,Open\n";
	my $ref = json_file_to_perl($json_destination);

	foreach my $item (@$ref) {
		$item -> {'Update_Date'} =~ /Date\((.*)\)/;
		# Time in milliseconds, convert to seconds.
		my $timestamp = $1;
		my $date = get_csv_date_string($timestamp / 1000);
		my $price = $item -> {'Bid_Close'};
		my $high_price = $item -> {'Bid_High'};
		my $low_price = $item -> {'Bid_Low'};
		my $open_price = $item -> {'Bid_Open'};
		print $csv "$date,$price,$high_price,$low_price,0,$open_price\n";
	}
	close $csv;
	`rm $json_destination`;
	print "...done\n";
}

sub get_url_date_string {
	my $time = shift;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
	$mon++;
	$year += 1900;
	return "$mon%2F$mday%2F$year";
}

sub get_csv_date_string {
	my $time = shift;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
	$mon++;
	$year += 1900;
	return sprintf "%02d/%02d/%4d", $mon, $mday, $year;
}
