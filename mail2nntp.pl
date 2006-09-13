#! /usr/bin/perl -w
# mail2nntp - Nicolas Lidzborski - http://cpc.freeshell.org/ - 2001-2003
# Process stdin (usually an email) to post it on a specified newsgroup server
# $Id: mail2nntp.pl,v 1.8 2003/06/19 23:53:08 cpc6128 Exp $
# mail2nntp is available under the GPL (http://www.gnu.org/licenses/gpl.txt).

use strict;
#use diagnostics;
use News::NNTPClient;

my $server		= 'localhost';
my $port		= '119';
my $debug		= '1';
my $login		= 'newsmaster';
my $password		= 'XXXXXXXX';
my $debugmode		= 1;	# Set this to 0 to enable posting
my $authmode		= 0;	# Set this to 1 to enable auth

#Default newsgroups headers
my $postinghost = "localhost";
my $newsgroup   = '';
my $approved	= "Approved: yes\n";	# Auto approval
my $organization = "Organization: Unknown.\n"; # Must be present
my $ua = "X-User-Agent: mail2nntp (http://sourceforge.net/projects/mail2nntp/)\n";
my $from;
my $to;
my $cc;
my $msgid;
my $path;
my $date;
my $subject;
my $newsgroups;
my $references;
my $content;
my $content_enc;
my $mime;
my $in_reply;
my @otherheaders;

# Final header and body
my @header;
my @body;
my $nextline;

# Get the newsgroup name on command line
if ($#ARGV == 0) {
	$newsgroup = $ARGV[0];
} else {
	die "usage: mail2nntp [newsgroup]\n";
}

while (<STDIN>) {


##############################################
# Header manipultion
##############################################

	chomp;

	for ($_) {
# Process multiline Content-Type
		if (/^Content-Type/) {
			$content=$_."\n";
			while ($nextline = <STDIN>) {
				chomp ($nextline);
				if ($nextline =~ m/^\s+/) {
					$content .= $nextline."\n";
				} else {
					$_ = $nextline;
					last;
				}
			}
		}

# Correct Message-ID case	
		if (/^Message-Id/i)  {
			s/^Message-Id/Message-ID/i;
			$msgid=$_."\n";
		}

		elsif (/^To/) {
# Grab 'To' header line(s)
# Do it while the line ends with ','
			$to=$_;
			while ($_=~/\,$/) {
				chomp ($_=<STDIN>);
				$to.=$_;
			}
			$to.="\n";
		}
		elsif (/^Cc/) {
# Grab 'Cc' header line(s)
# Do it while the line ends with ','
			$cc=$_;
			while ($_=~/\,$/) {
				chomp ($_=<STDIN>);
				$cc.=$_;
			}
			$cc.="\n";
		}
		elsif (/^In-Reply-To/) {
# Grab 'In-Reply-To' header line
			$in_reply=$_."\n";
		}
		elsif (/^From/) {
# Transform 'From' header line to 'Path' header

			s/^From:\s+(.*) <(.*)>/From: $2 ($1)/;
			$from=$_."\n";
			if(s/^From:\s+(\S+)@(\S+).*/Path: $2!$1/ ||
					s/^From:\s+(\S+)[^@]*$/Path: $1\n/){
				$path=$_."\n";
			}
		}
		elsif (/^Date/) {
			$date=$_."\n";
		}
		elsif (/^Subject/) {
			$subject=$_."\n";
		}
		elsif (/^Approved/) {
			$approved=$_."\n";
		}
		elsif (/^Organization/) {
			$organization=$_."\n";
		}
		elsif (/^References/) {
			$references=$_."\n";
		}
		elsif (/^MIME-Version/) {
			$mime=$_."\n";
		}
		elsif (/^Content-Transfer-Encoding/) {
			$content_enc=$_."\n";
		}
		elsif (/^X-Face|^X-Mailer/){
			push @otherheaders,$_."\n";
		}
	}
#Repeat until end of headers
	last if /^$/;
}

# Header parsing finished
# Now generating missing headers and sending message

# Minimum headers
die "missing headers" unless defined($date) && defined($from);

# Generate own Message-ID if none found
if (!defined($msgid)) { 
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	my $madeupid = "\<$year$mon$mday.$hour$min$sec.$$\@$postinghost\>";
	$msgid = "Message-ID: $madeupid\n";
}
# Generate 'References' header from 'In-Reply-To'
if (!defined($references) && $in_reply) {
	$in_reply =~ m/(<[^@>]+@[^>]+>)/;
	$references = "References: $1\n" if $1;
}

# Default subject
if (!defined($subject)) {$subject = "Subject: unknown\n"};

# Posting newsgroup(s)
$newsgroups = "Newsgroups: ".$newsgroup."\n";

###############################################################
# Generating post

push @header,$from 	if defined($from);
#push @header,$to	if defined($to);
push @header,$cc	if defined($cc);
push @header,$subject	if defined($subject);
push @header,$date	if defined($date);
push @header,$in_reply	if defined($in_reply);
push @header,$msgid	if defined($msgid);
push @header,$references	if defined($references); 
push @header,$ua	if defined($ua); 
push @header,$organization	if defined($organization);
push @header,$newsgroups	if defined($newsgroups);
push @header,$path	if defined($path);
push @header,$approved	if defined($approved);
push @header,$content	if defined($content);
push @header,$content_enc	if defined($content_enc);
push @header,$mime	if defined($mime);
push @header,@otherheaders;

# Ready to send the message

# Separation between headers and body
push @header,"\n";

# Grabing body
push @body,$_ while <STDIN>;

if ($debugmode){
	print @header;
	print @body;
	print "\n";
}else{
#Open connection to the NNTP server now that the message is ready.
	my $c = new News::NNTPClient($server, $port, $debug);

#Some servers require this command to process NNTP client commands. 
	$c->mode_reader();

#Authentification on the NNTP server to post the message
if ($authmode) {
	$c->authinfo($login,$password);
}

#Post the message on the server
	$c->post(@header,@body);
}
#Message posting example
#$c->post("Newsgroups: alt.test", "Subject: test2", "From: Nicolas <cpc@localhost>", "Date:  Wed, 29 Feb 2002 12:05:01 -0800 (PST)","", "Not a lot of other postings today");
