#!/usr/bin/perl -w
use strict;
use warnings;

my $inputdir = "./";
my $outputdir = $inputdir."/Organized - ".`date`;
my @problemfiles;
my $bypass;

sub prompt {
	my $type = shift;
	my $filename = shift;
	my $default = shift;
	$default =~ s/[:"'\(\)]/-/g;
	chomp $default;
	my $input = "";
	unless ($default) { $default = "Unknown" }
	unless ( $bypass ) {
		print $filename."\n";
		print "Please give a ".$type.". If you don't know just hit enter [".$default."]:\n";
		$input = <>;
		chomp $input;
		$input =~ s/[:"'\(\)]/-/g;
	} else {
		return $default;
	}
	if ( "" ne $input ) { return $input; } else { return $default; }
}

sub moveit {
	my $source = shift;
	my $dest = shift;
	my $info = shift; #this is a hashref
	my $file = "[".(split(" of ", (split("/", $info->{"Track"}))[0]))[0]."]".$info->{"Name"}.".".$info->{"EXT"};
	$file =~ s/\//,/g;
	unless ( `mkdir -p "$dest" && cp "$source" "$dest$file"` ) {
		if ( "mp3" eq $info->{"EXT"} ) { system('mid3v2 -a "'.$info->{"Artist"}.'" -A "'.$info->{"Album"}.'" -T "'.$info->{"Track"}.'" -t "'.$info->{"Name"}.'" "'.$dest.$file.'"'); }
		if ( "m4a" eq $info->{"EXT"} ) { system('mp4tags -a "'.$info->{"Artist"}.'" -A "'.$info->{"Album"}.'" -t "'.$info->{"Track"}.'" -s "'.$info->{"Name"}.'" "'.$dest.$file.'"'); }
		if ( "ogg" eq $info->{"EXT"} ) { system('vorbiscomment -at \'album='.$info->{"Album"}.'\' -t \'artist='.$info->{"Artist"}.'\' -t \'title='.$info->{"Name"}.'\' -t \'tracknumber='.$info->{"Track"}.'\' "'.$dest.$file.'"'); }
		if ( "flac" eq $info->{"EXT"} ) { system('metaflac --remove-tag=ALBUM --set-tag=\'ALBUM='.$info->{"Album"}.'\' --remove-tag=ARTIST --set-tag=\'ARTIST='.$info->{"Artist"}.'\' --remove-tag=TITLE --set-tag=\'TITLE='.$info->{"Name"}.'\' --remove-tag=TRACKNUMBER --set-tag=\'TRACKNUMBER='.$info->{"Track"}.'\' "'.$dest.$file.'"');}
	} else {
		push( @problemfiles, $source );
	}
}

sub getinfo { # Need to troubleshoot m4a, it doesn't always get the needed tags and assumes unknown.
	my $file = $_;
	my $filetype = (split(/\./, $file))[-1];
	my @info;
	if ( "mp3" eq $filetype ) { @info = `mid3v2 "$file"`; }
	if ( "m4a" eq $filetype ) { @info = `mp4info "$file"`; @info = @info[5..$#info]; }
	if ( "ogg" eq $filetype ) { @info = `vorbiscomment "$file"`; }
	if ( "flac" eq $filetype ) { @info = `metaflac --list --block-type=VORBIS_COMMENT "$file"`; @info = @info[6..$#info]; }
	my ($name, $album, $artist, $track);
	foreach (@info) {
		my $entry = $_;
		my $type = "";
		my $data = "";
		if ("flac" eq $filetype) { $entry = (split(": ", $entry))[1]; }
		if ("m4a" eq $filetype) { ($type, $data) = split(": ", $entry); }
		else { ($type, $data) = split("=", $entry); }
		$type =~ s/ //g;
		if ($data) { 
			$data =~ s/[:"'\(\)]/-/g;
			chomp $data; 
		}
		if ($type =~ m/((T|t)(IT(1|2)|itle|ITLE))|(Name)/ ) { $name = $data; }
		if ($type =~ m/(T|t)(RCK|RACK|rack)(number|NUMBER)*/ ) { $track = $data; }
		if ($type =~ m/((A|a)(rtist|RTIST))|(T(SOP|PE(1|2)))/ ) { $artist = $data; }
		if ($type =~ m/((A|a)(lbum|LBUM))|(TALB)/ ) { $album = $data; }
	}
	unless ( $artist ) { $artist = prompt("artist", $file, "Artist Unknown"); }
	unless ( $album ) { $album = prompt("album", $file, "Album Unknown"); }
	unless ( $name ) { $name = prompt("name", $file, `basename "$file" .$filetype`); }
	unless ( $track ) { 
		$track = "0";
		if ( ("m4a" eq $filetype) || ("mp3" eq $filetype) ) { $track .= "/1"; }
	}
	return ("Name"=>$name, "Artist"=>$artist, "Album"=>$album, "Track"=>$track, "EXT"=>$filetype);
}

sub getfiles {
	unless ( 1 < $bypass ) {
		print "Please give an input directory (This is where all your current music is now):\n";
		$inputdir = <>;
		chomp $inputdir;
	}
	my @filelist = `find ./$inputdir -type f -name *.mp3`;
	push( @filelist, `find ./$inputdir -type f -name *.m4a` );
	push( @filelist, `find ./$inputdir -type f -name *.ogg` );
	push( @filelist, `find ./$inputdir -type f -name *.flac` );
	return @filelist;
}

sub processfiles {
	my @list = @_;
	unless ( 1 < $bypass ) {
		print "Please give an output directory (This is were the new library will be built):\n";
		$outputdir = <>;
		chomp $outputdir;
	}
	my $progress=0;
	my $total = scalar(@list);
	foreach (@list) {
		$_ =~ s/\$/\\\$/g;
		chomp $_;
		my %info = getinfo($_);
		my $outpath = "./".$outputdir."/".$info{"Artist"}."/".$info{"Album"}."/";
		moveit($_, $outpath, \%info);
		$progress++;
		printf "(%d/%d) %3.0d%% [%-20.*s]\r", $progress, $total , $progress/$total*100, int($progress/$total*20), "="x20;
	}
	print "Organization Complete!\n\n";
	if (@problemfiles) {
		print "These files had problems:\n";
		foreach(@problemfiles) { print; }
	}
}

processfiles(&getfiles);
