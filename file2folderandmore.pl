#!/bin/perl -w

use strict;
use warnings;
use Term::ANSIColor;

# v1 : initial release
# v2 : enhanced action, sanitizing string option
# v3 : colored console
# Copyright 2016 FCO

# renomme un fichier seul et meta ou repertoire et ses fichiier et meta
# transfere un fichier et meta dans un repertoire
# transfere tous les fichier et meta d'un repertoire vers des repertoires
# enleve un repertoire et deplace fichier et meta

use constant MEDIATYPES  =>  ['mkv', 'avi', 'mp4', 'iso', 'ts', 'flv', 'rmv', 'vob', 'm2ts', 'divx', 'ino'];
use constant PICTURETYPE =>  ['jpg', 'png', 'gif'];
use constant NFOFILE     =>  'nfo';
use constant TFILE       =>  'f';
use constant TDIR        =>  'd';

my $SAN = 0;

my $input;
my %swaction = ();
my ($action, $shellaction, $ret);
my $curscript = $0;

%swaction = ( 1,  " 1  - Rename this media file or this folder and it's content (auto).",
              2,  " 2  - Move this media files to folder with same name.",
              3,  " 3  - Move and sanitize this media files to folder with same name.",
              4,  " 4  - Move all media files from this folder to sub folders.",
              5,  " 5  - Move and sanitize all media files from this folder to sub folders.",
              6,  " 6  - Move media files from this folder to parent folder.",

              90,  "----------------------------",
              98,  " 98 - Sanitize name (on/off).",
              99,  " 99 - Add this script to context menu (only Windows compatible).",
              100, " 0  - Quit");

&clearScreen();

&info('Header');   
           
!defined $ARGV[0] && do { &info('NoInput'); delete @swaction{qw(1 2 3 4 5 6 90)}; $input = '';};
defined $ARGV[0] && do { $input = $ARGV[0];};
$shellaction = $ARGV[1] if ( defined $ARGV[1] );

# first and simple string protection
$input =~ s/(\\|\/\/)/\//g;
$input =~ s/(^\s+|^\t+|\s+$|\t+$)//g;
$curscript =~ s/(\\|\/\/)/\//g;

$SAN = &checkSanitize($curscript, \%swaction, 98);

$input =~ /^(info|\?|h|help)$/ && do { &info('Help'); exit 0; };

$action = (!defined $shellaction) ? &selectAction( $input, \%swaction ):&confirmAction( $shellaction,  $input, \%swaction);

SWITCH: {
    $action == 1 && do { $ret = &renameFilesOrFolder($input); last SWITCH; };
    $action == 2 && do { $ret = &moveFiles2Folder($input,0); last SWITCH; };
    $action == 3 && do { $ret = &moveFiles2Folder($input,1); last SWITCH; };
    $action == 4 && do { $ret = &moveAllFiles2Folders($input,0); last SWITCH; };
    $action == 5 && do { $ret = &moveAllFiles2Folders($input,1); last SWITCH; };
    $action == 6 && do { $ret = &moveFilesOutFolder($input); last SWITCH; };
    $action == 98 && do { $SAN = &sanitizeONOFF($curscript); last SWITCH; };
    $action == 99 && do { $ret = &toContext($curscript); last SWITCH; };
    $action == 0 && do { print "Good choice, bye.\n"; last SWITCH; };
    &info('BadSelect');
}

exit;

# ---------------   SUB Section   --------------

sub info($) {
    my $_action = shift;
    SWITCH: {
        $_action eq 'NoInput' && do { print colored (" No file or directory on input.", "bold on_blue"), "\n\n"; last SWITCH; };
        $_action eq 'Help' && do { &help(); last SWITCH; };
        $_action eq 'Header' && do { &header(); last SWITCH; };
        $_action eq 'BadSelect' && do { print colored (" Bad choice.", "bold red"), "\n"; last SWITCH; };
        $_action eq 'InvalidOS' && do { print colored (" You are not on Win32 system.", "bold red"), "\n"; last SWITCH; };
    }
    return;
}

sub help () {
    print "HELP", "\n";
}

sub header () {
    print " ===================================================================", "\n";
    print "                    File to Folder And More", "\n";
    print " ===================================================================", "\n";
    print " ===================================================================", "\n";
    print "\n";
}

sub toContext($) {
	my $_script = shift;
	my $_regstr;
	my $_regfile;
	my $_batfile;
	my $_str;
    my %_swaction = ();
    my $_action;
    my $_input;
    
	# only on Windows plateform
	$^O !~ /^MSWin32$/ && do {&info('InvalidOS'); return;};
	
    system("cls");
    
	$_batfile = &dirname($_script) . '/' . &file_wo_ext($_script) . '.bat';
	$_str     = $_batfile;
	$_str     =~ s/\//\\\\/g;
	$_regfile = &dirname($_script) . '/' . &file_wo_ext($_script) . '.reg';
    
	# generating bat file for call in contextual menu
	open (BATF, '>' . $_batfile) or die "Impossible de créer le fichier : " . $_batfile . "\n";
	print BATF "\@echo off", "\n";
    print BATF "REM File2Folder launcher", "\n";
    print BATF "REM Dont't edit, generated automatically", "\n";
    print BATF "REM copyright 2013 FCO", "\n";
	print BATF "set \"currentpath=%~dp0\"", "\n";
	print BATF "if not exist %1 goto fin", "\n";
	print BATF "%currentpath%\\file2folderandmore.pl %1", "\n";
	print BATF ":fin", "\n";
	close(BATF);
	
	# adding contextual menu for directory and mediafile in registry 
	open (REGF, '>' . $_regfile) or die "Impossible de créer le fichier : " . $_regfile . "\n";
	print REGF "Windows Registry Editor Version 5.00", "\n";
	print REGF "\n";
	print REGF "[HKEY_CLASSES_ROOT\\Directory\\shell\\file2folderandmore]", "\n";
	print REGF "@=\"Lancer dans File2Folder and More\"", "\n";
	print REGF "\"icon\"=\"%SystemRoot%\\\\system32\\\\imageres.dll,111\"", "\n";
	print REGF "\n";
	print REGF "[HKEY_CLASSES_ROOT\\Directory\\shell\\file2folderandmore\\command]", "\n";
	print REGF "@=\"\\\"" . $_str . "\\\" \\\"%1\\\"\"", "\n";
	print REGF "\n";
	
	for my $_ftype ( @{+MEDIATYPES} ) {
		print REGF "[HKEY_CLASSES_ROOT\\SystemFileAssociations\\." . $_ftype . "\\Shell]", "\n";
		print REGF "\n";
		print REGF "[HKEY_CLASSES_ROOT\\SystemFileAssociations\\." . $_ftype . "\\Shell\\file2folderandmore]", "\n";
		print REGF "@=\"Lancer dans File2Folder and More\"", "\n";
		print REGF "\"icon\"=\"%SystemRoot%\\\\system32\\\\imageres.dll,111\"", "\n";
		print REGF "\n";
		print REGF "[HKEY_CLASSES_ROOT\\SystemFileAssociations\\." . $_ftype . "\\Shell\\file2folderandmore\\command]", "\n";
		print REGF "@=\"\\\"" . $_str . "\\\" \\\"%1\\\"\"", "\n";
		print REGF "\n";
	}
	
	close(REGF);
	# launching reg file
	exec($_regfile);

}

sub selectAction($$) {
	my $_input = shift;
    my $_swactions = shift;
	my $_r = 0;
	
	print "Choose your action ";
	print "for : ", "\n\n", "  ", ( -d $_input ) ? TDIR:TFILE , " : ", colored($_input, "bold green"), "\n\n" if ( $_input ne '' );
    print " : ", "\n\n" if ( $_input eq '' );
    for my $_action ( sort {$a <=> $b} keys %$_swactions ) {
        print $_swactions->{$_action}, "\n";
    }
	print "\n";
	print "Choice [0] : ";
	chomp ($_r = <STDIN>);
	$_r =~ s/^\s+|\s+$|^\t+|\t+$//g;
	$_r = 0 if ( $_r eq '' || $_r !~ /^[0-9]+$/ );
	return $_r
}

sub confirmAction($$$) {
	my $_action = shift;
	my $_input  = shift;
    my $_swaction = shift;
	my $_r;
	my $_return = 0;
	
	print "Your action for : ", $_input, "\n";
	print "Is ", $_swaction->{$_action}, "\n\n";
	print "Are you sure ? [N]/Y : ";
	chomp ($_r = <STDIN>);
	$_r = "N" if ( $_r !~ /^y|Y$/ );
	$_return = $_action if $_r !~ /^N$/;
	return $_return;
}

sub renameFilesOrFolder($) {
	my $_input = shift;
	my $_r = 0;
	my $_type = 'na';
	my $_prevtype = 'na';
	my $_mediafile = '';
	my $_newName = '';
	my $_t = '';
	
	($_r, $_type) = &checkInputType ($_input, \$_mediafile);
	&outerror ( $_type ) if ( $_r == 0 );
	
	if ( $_type eq TDIR ) { 
		# rename dir
		print "\n";
		print "Rename DIR : ", $_input, "\n";
		print "================================================================", "\n";
		($_r, $_newName) = &chooseName ( TDIR, &basename($_input), &dirname($_input) );
		($_r, $_t) = &reName ( TDIR, &basename($_input), &dirname($_input), $_newName, &dirname($_input));
		&outerror ( 'ren' ) if ( $_r == 0 );
		# change to file if media with same name found in it
		if ( $_mediafile ne '' ) {
			$_prevtype = TDIR;
			$_type =  TFILE;
			$_input = &dirname($_input) . '/' . $_newName . '/' . &basename($_mediafile);
			$_newName .= '.' . &file_ext($_mediafile);
		}
	}

	if ( $_type eq TFILE ) {
		print "\n";
		print "Rename FILES like : ", $_input, "\n";
		print "================================================================", "\n";
		($_r, $_newName) = &chooseName ( TFILE, &basename($_input), &dirname($_input) ) if ( $_prevtype ne TDIR);
		($_r, $_t) = &reName ( TFILE, &basename($_input), &dirname($_input), $_newName, &dirname($_input));
		&outerror ( 'ren' ) if ( $_r == 0 );
	}
	return $_r
}

sub moveFiles2Folder($$) {
	my $_input = shift;
    my $_san = shift;
	my $_r;
	my $_type = 'na';
	my $_mediafile = '';
	my $_newDir = '';
	my $_t = '';
	
	($_r, $_type) = &checkInputType ($_input, \$_mediafile);
	&outerror ( $_type ) if ( $_r == 0 || $_type eq TDIR);
	
	($_r, $_newDir) = &buildDir ( $_input, $_san );
	&outerror ( 'bd' ) if ( $_r == 0 );
	
	print "\n";
	print "Create DIR : ", $_newDir, "\n";
	print "================================================================", "\n";
	$_r = &createDir ( $_newDir);
	&outerror ( 'mkd' ) if ( $_r == 0 );
	
	print "\n";	
	print "Move FILES like : ", $_input, "\n";
	print "================================================================", "\n";
	$_r = &moveFiles ( $_input, $_newDir, $_san);
	&outerror ( 'mvf' ) if ( $_r == 0 );

	return $_r
}

sub moveAllFiles2Folders($$) {
	my $_input = shift;
    my $_san = shift;
	my $_r;
	my $_type = 'na';
	my $_mediafile = '';
	my $_newDir = '';
	my $_t = '';
	my @_dirFiles;
	
	# at least one is good
	($_r, $_type) = &checkInputType ($_input, \$_mediafile);
	&outerror ( $_type ) if ( $_r == 0 || $_type eq TFILE);
	
	opendir my($_dh), $_input or return ( 0, "Couldn't open dir : " . $_input . "': " . $! );
	@_dirFiles = grep { !/^\./ } readdir $_dh;
	closedir $_dh;
	foreach my $_dirFile( @_dirFiles ) {
		$_r = &moveFiles2Folder($_input . '/' . $_dirFile, $_san) if ( &in_array ( MEDIATYPES, &file_ext($_dirFile) ) && -f $_input . '/' . $_dirFile );
	}

	return $_r
}

sub checkSanitize($$$) {
    my $_base = shift;
    my $_swaction = shift;
    my $_idaction = shift;
    my $_r;
    my $_checkname = &dirname ($_base) . '/.' . &file_wo_ext($_base);
    
    if ( -f $_checkname ) {
        print colored ("SANITIZE is ON", "bold magenta"), "\n";
        $_swaction-> {$_idaction} .= '[ACTIVE]';
        $_r = 1;
    } else { $_r = 0; }
    
    return $_r;
}

sub sanitizeONOFF($) {
    my $_base = shift;
    my $_r;
    
    my $_checkname = &dirname($_base) . '/.' . &file_wo_ext($_base);
    
    if ( -f $_checkname ) {
        unlink $_checkname;
        $_r = 0;
    } else {
        open HANDLE, ">" . $_checkname or die "touch " . $_checkname . ": $!\n"; 
        close HANDLE;
        $_r = 1;
    }
    return $_r;
}

sub sanitizeFileAndFolderName($$$) {
	my $_input = shift;
    my $_sanauto = shift;
    my $_type = shift;
    my $_name;
    my $_ext;
	my $_r = '';
	
	my %_cleanchar = (
        'À', 'a', 'Á' , 'a', 'Â' , 'a', 'Ä' , 'a', 'à' , 'a', 'á' , 'a', 'â' , 'a', 'ä' , 'a',
        'È', 'e', 'É' , 'e', 'Ê' , 'e', 'Ë' , 'e', 'è' , 'e', 'é' , 'e', 'ê' , 'e', 'ë' , 'e', '€' , 'e',
        'Ì', 'i', 'Í' , 'i', 'Î' , 'i', 'Ï' , 'i', 'ì' , 'i', 'í' , 'i', 'î' , 'i', 'ï' , 'i',
        'Ò', 'o', 'Ó' , 'o', 'Ô' , 'o', 'Ö' , 'o', 'ò' , 'o', 'ó' , 'o', 'ô' , 'o', 'ö' , 'o',
        'Ù', 'u', 'Ú' , 'u', 'Û' , 'u', 'Ü' , 'u', 'ù' , 'u', 'ú' , 'u', 'û' , 'u', 'ü' , 'u', 'µ' , 'u',
        'Œ', 'oe', 'œ' , 'oe',
        'ç', 'c',
        '#', '', 'µ', '', '~', '', '*', '', '&', '', '$', '', '%', '', '?', '', '@', '', '^', ''
    );
    
    my @_regrep = (
        '\s', '\t', ' ', '-', '_', ';', ',', '\+' ,':', ';', '!', '\{', '\}', '\[', '\]', '\(', '\)', '\''
    );

    print "  Intial name : ", $_input, "\n" if ($_sanauto == 1);

    if ( $_sanauto == 1 ) {
        if ( $_type eq TDIR) {
            $_name = $_input;
            $_ext = '';
        } else {
            $_name = &file_wo_ext($_input);
            $_ext = '.' . &file_ext($_input);
        }
        # lower case
        $_name = lc($_name);
        # replace char
        foreach my $_char (split //, $_name) {
            $_r .= (! defined $_cleanchar{$_char}) ? $_char : $_cleanchar{$_char};
        }
        # regex multi replace
        foreach my $_sym ( @_regrep ) {
            my $regex = $_sym.'+';
            $_r =~ s/$regex/./g;
        }
        
        # replace multi separator and capitalize
        $_r =~ s/^(.)/\U$1/;
        $_r =~ s/\.+(.)/.\U$1/g;
        $_r .= $_ext;
    } else { $_r = $_input; }
	return $_r
}

sub moveFilesOutFolder($) {
	my $_input = shift;
	my $_r;
	my $_type = 'na';
	my $_mediafile = '';
	my $_Dir = '';
	my $_t = '';
	my @_dirFiles;
	
	# at least one is good for directory
	($_r, $_type) = &checkInputType ($_input, \$_mediafile);
	&outerror ( $_type ) if ( $_r == 0 );
	
	$_Dir = $_input;
	$_Dir = &dirname($_input) if ($_type eq TFILE );
	
	opendir my($_dh), $_Dir or return ( 0, "Couldn't open dir : " . $_Dir . "': " . $! );
	@_dirFiles = grep { !/^\./ } readdir $_dh;
	closedir $_dh;
	foreach my $_dirFile( @_dirFiles ) {
		if ( &in_array ( MEDIATYPES, lc(&file_ext($_dirFile)) ) && -f $_Dir . '/' . $_dirFile ) {
			($_r, $_t) = &moveFiles ( $_Dir . '/' . $_dirFile, &dirname($_Dir), 0);
			&outerror ( 'ren' ) if ( $_r == 0 );
		}
	}

	return $_r
}

sub checkInputType ($$) {
	my $_input = shift;
	my $_media = shift;
	my $_dh;
	my $_r = 0;
	my $_t = '';
	my $_ext = '';
	my $_dirBaseName = '';
	my $_regex = '';
	my @_dirFiles;
	
	$$_media = '';
	
	if ( -d $_input ) { 
		$_t = TDIR;
		opendir my($_dh), $_input or return ( 0, "Couldn't open dir : " . $_input . "': " . $! );
		@_dirFiles = grep { !/^\./ } readdir $_dh;
		closedir $_dh;
		$_regex = '^' . quotemeta (&basename($_input)) . '(\.|_|-)([^\.]+)\.?([^\.]+)$';
		foreach my $_dirFile( @_dirFiles ) {
			#print &file_ext($_dirFile), " ",$_input. "/" . $_dirFile, "\n";
			if ( &in_array ( MEDIATYPES, lc(&file_ext($_dirFile)) ) && -f $_input. "/" . $_dirFile ) {
				$_r = 1 ;
				if ($_dirFile =~ m/$_regex/) {
					$$_media = $_dirFile;
					last;
				}
			}
		}
		#@files = map { $path . '/' . $_ } @files;
		
	}
	elsif ( -f $_input ) { 
		$_t = TFILE;
		$_r = &in_array ( MEDIATYPES, lc(&file_ext($_input)));
	}
	else { $_r = 0; $_t = 'bad input type';}
	
	return ($_r, $_t);
}

sub outerror($) {
	my $_input = shift;
	my $_errorText = '';
	print colored("ERROR", "bold on_red"), "\n";
    SWITCH: {
        $_input eq TDIR && do { $_errorText = 'Le repertoire ne contient pas de media valide.'; last SWITCH; };
        $_input eq TFILE && do { $_errorText = 'Le media n\'existe pas.'; last SWITCH; };
        $_input eq 'exist'  && do { $_errorText = 'Un repertoire ou fichier de ce nom existe deja.'; last SWITCH; };
        $_input eq 'ntdo'  && do { $_errorText = 'Rien a faire.'; last SWITCH; };
        $_input eq 'ren'  && do { $_errorText = 'Probleme de renommage.'; last SWITCH; };
        $_input eq 'bd'  && do { $_errorText = 'Cannot build dir.'; last SWITCH; };
        $_input eq 'mkd'  && do { $_errorText = 'Cannot create dir.'; last SWITCH; };
        $_input eq 'mvf'  && do { $_errorText = 'Cannot move file.'; last SWITCH; };
        $_errorText = 'Probleme inconnue.';
    }
    print " - ", $_input, " : ", $_errorText, "\n";	
    exit 0;
}

sub chooseName ($$$) {
	my $_type = shift;
	my $_oldname = shift;
	my $_path = shift;
    my $_saninput = &sanitizeFileAndFolderName($_oldname, $SAN, $_type);
	my $_read ;
	my $_r = 0;
	my $_tmp = '';
	my $_tmp2 = '';
    
	print "Choose new name for : ", $_oldname, "\n";	
	print "\n";
	print "Choice [", $_saninput, "] (Q quit): ";
	chomp ($_read = <STDIN>);
	
    $_read = $_saninput if ( $_read eq '' );
    
	$_read =~ s/^\s+|\s+$|^\t+|\t+$//g;
	
	if ( $_read ne $_oldname && $_read ne '' && $_read !~ /^(q|Q)$/ ) {
		if ( $_type eq TFILE && &file_ext($_oldname) ne &file_ext($_read) ) {
			$_read .= '.' . &file_ext($_oldname);
		}
		($_r, $_tmp2) = &checkInputType ($_path . "/" . $_read, \$_tmp) ;
	} else { &outerror ( 'ntdo' ); }
	&outerror ( 'exist' ) if ( $_r == 1 );
	return ($_r, $_read);

}

sub reName ($$$$$) {
	my $_type = shift;
	my $_oldname = shift;
	my $_oldpath = shift;
	my $_newname = shift;
	my $_newpath = shift;
	my $_read = '';
	my $_r = 1;
	
	
	if ( $_type eq TDIR ) {
		print "\n";
		print "  Renamming ", $_type, " : ", $_oldpath . '/' . $_oldname, "\n", "    to ", $_newpath . '/' . $_newname, "\n";
		rename ( $_oldpath . '/' . $_oldname, $_newpath . '/' . $_newname ) or return ( 0, "Couldn't rename dir : " . $_oldpath . '/' . $_oldname . "': " . $!) ;
		return ( 1, '');
	}
	elsif ( $_type eq TFILE ) {
		print "\n";
		my $_regex = '^' . quotemeta (&file_wo_ext($_oldname)) . '(\.|_|-)([^\.]+)\.?([^\.]+)$';
		opendir my($_dh), $_oldpath or return ( 0, "Couldn't open dir : " . $_oldpath . "': " . $! );
		my @_dirFiles = grep { !/^\./ } readdir $_dh;
		closedir $_dh;

		foreach my $_dirFile( @_dirFiles ) {
			if ( -f $_oldpath . "/" . $_dirFile && $_dirFile =~ m/$_regex/i ) {
				my $_oldname_wo_ext = quotemeta (&file_wo_ext($_oldname));
				my $_newname_wo_ext = &file_wo_ext($_newname);
				my $_newFileName = $_dirFile;
				$_newFileName =~ s/$_oldname_wo_ext/$_newname_wo_ext/ ;
				print "  Renamming ", $_type, " : ", $_oldpath . '/' . $_dirFile, "\n", "    to ", $_newpath . '/' . $_newFileName, "\n";
				rename ( $_oldpath . '/' . $_dirFile, $_newpath . '/' . $_newFileName ) or $_r=0;
				if ($_r == 0) {
					print "Couldn't rename file : ", $_dirFile, "': ", $!, "\n";
					print "\n";
					print "Choice [S]top/Continue : ";
					chomp ($_read = <STDIN>);	
					next if ( $_read =~ /^c$/i );
					return ( 0, "Stopping rename files");
				}
			}
		}
		return ( 1, '');
	}
	else { return (0,'Bad Type');}
}

sub buildDir ($$) {
	my $_input = shift;
    my $_san = shift;
	my $_newpath = '';
	my $_tmp1 = '';
	my $_tmp2 = '';
	my $_r = 1;
	
	$_newpath = &dirname ($_input) . '/' . &sanitizeFileAndFolderName( &file_wo_ext($_input), $_san, TDIR );
	
	if ( -d $_newpath ) {
		($_r, $_tmp2) = &checkInputType ( $_newpath, \$_tmp1 ) ;
		$_r = 1 if ($_r == 0);
	}
	return ( $_r, $_newpath);
}

sub createDir ($) {
	my $_input = shift;
	my $_r = 1;
	
	if ( ! -e $_input) {
		print "  Creating dir : ", $_input, "\n";
		mkdir $_input or $_r = 0 ;
	} else { print "  Already exist dir : ", $_input, "\n"; }
	return $_r;
}

sub moveFiles ($$$) {
	my $_input = shift;
	my $_dir = shift;
    my $_san = shift;
	my $_r = 1;
	my $_curdir = '';
	
	$_curdir = &dirname($_input);
	
	my $_regex = '^' . quotemeta (&file_wo_ext($_input)) . '(\.|_|-)([^\.]+)\.?([^\.]+)$';
	opendir my($_dh), $_curdir or return 0;
	my @_dirFiles = grep { !/^\./ } readdir $_dh;
	closedir $_dh;

	foreach my $_dirFile( @_dirFiles ) {
		if ( -f $_curdir . "/" . $_dirFile && $_dirFile =~ m/$_regex/i ) {
			print "  Moving ", $_curdir, "/" , $_dirFile, "\n", "    to ", $_dir . '/' . &sanitizeFileAndFolderName($_dirFile, $_san, TFILE), "\n";
			rename ( $_curdir . "/" . $_dirFile, $_dir . '/' . &sanitizeFileAndFolderName($_dirFile, $_san, TFILE) ) or return 0;
		}
	}
	return 1;

}

sub basename($) {
    # needed format  /aaaa/bbb/bbbb/d.toto
    # out : d.toto
	my $_in = shift;
	$_in =~ s!^(?:.*/)?(.+?)$!$1!;
	$_in =~ s/\/+$//g;
	return $_in;
}

sub file_ext($) {
    # needed format  /aaaa/bbb/bbbb/d.toto
    # out : toto
	my $_in = shift;
	$_in = ($_in =~ m/([^.]+)$/)[0] ;
	$_in =~ s/\/+$//g;
	return $_in;
}

sub file_wo_ext($) {
    # needed format  /aaaa/bbb/bbbb/d.toto
    # out : d
	my $_in = shift;
	$_in =~ s!^(?:.*/)?(.+?)(?:\.[^.]*)?$!$1! ;
	$_in =~ s/\/+$//g;
	return $_in;
}

sub dirname($) {
    # needed format  /aaaa/bbb/bbbb/d.toto
    # out : /aaaa/bbb/bbbb
	my $_in = shift;
	$_in =~ s!/?[^/]*/*$!!;
	$_in =~ s/\/+$//g;
	$_in = '.' if ( quotemeta ($_in) =~ /^$/ );
	return $_in;
}

 sub in_array ($$) {
     my $_arr = shift;
	 my $_search = shift;
     my %items = map {$_ , 1} @$_arr;
     return (exists($items{$_search}))?1:0;
 }
 
 sub clearScreen() {
    ($^O =~ /^MSWin32$/) ?  system("cls"):system("clear");
 }
 