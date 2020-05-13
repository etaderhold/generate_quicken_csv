# Quicken Mac 2017 CSV Generator

Quicken's 2017 Mac version stopped supporting stock price downloads at the end of April 2020. This was the only network feature of the app that I used, and I didn't want to start an annual subscription just to keep these prices reasonably well up to date. Quicken does support CSV imports. I wrote this Perl script to grab data on investments I own from publicly avaliable sources, converting it into Quicken-readable CSV files as needed. 

The script takes a JSON input file with the following format (minus comments, they don't parse).

	{
		"investments": [
			# "ticker" type is a regular stock/mutual fund/ETF with a ticker symbol that Yahoo Finance understands.
			{
				"type": "ticker",
				# Required. Ticker symbol.
				"ticker": "VTSAX",
				# Optional. Used as the file name prefix for the CSV output file.
				"description": "Vanguard Total Stock Market Admiral"
			},
			# "vanguard_trust" type is for fancy investment trusts held in workplace plans.
			{
				"type": "vanguard_trust",
				# Required. Check your plan account for the applicable four-digit fund ID.
				"id": "7555",
				# Optional. Used as the file name prefix for the CSV output file.
				"description": "Vanguard Total Bond Market Trust"
			},
			# "vanguard_529" type is for portfolio options in Vanguard's 529 plan.
			{
				"type": "vanguard_529",
				# Required. Check the portfolio info page URL (i.e. https://investor.vanguard.com/529-plan/profile/overview/4509) for the four-digit fund ID.
				"id": "4509",
				# Optional. Used as the file name prefix for the CSV output file.
				"description": "529 Aggressive Growth Portfolio"
			},
			# "precious_metals" type is for precious metal prices.
			{
				"type": "precious_metals",
				# Required. G for gold, S for silver, P for platinum, and L for palladium
				"metal": "G",
				# Optional. Used as the file name prefix for the CSV output file.
				"description": "Gold"
			}

		]
	}

The script takes one command-line argument: the path to the input JSON file. If it's called investments.json, the command to download the CSVs is simply

	perl generate_quicken_csv.pl investments.json

System requirements:
* standard Unix command-line tools (mkdir, mv, rm, grep)
* perl
* wget
