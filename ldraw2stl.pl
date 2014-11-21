#!/usr/bin/perl
use warnings;
use strict;
use Data::Dump::Streamer;
use Math::Geometry;
use Math::MatrixReal;
#use Data::Dump::Streamer 'Dump', 'Dumper';
use 5.10.0;
no warnings 'experimental';
use autodie;
use strictures 1;
use Math::Round;
use Imager;
use Term::ProgressBar;
use JSON;
use Try::Tiny;

#if(!$ARGV[0] || !-e $ARGV[0]) {
#    usage();
#    exit;
#  }
print "Reading color map & generating texture\n";
my ($colorinfo, $img) = read_colors('LDConfig.ldr');
$img->write(file=>'ldraw_texture.png');
print "Done colormapping\n";

binmode \*STDOUT, ':utf8';

$|=1;
my @names = @ARGV;
@names = glob 'parts/*.dat' if not @names;
my $prog = Term::ProgressBar->new({ count => 0+@names,
                                  ETA => 'linear'});
my $count=0;
my $next_up=0;
for my $filename (@names) {
  #print "$filename:\n";
  my ($obj, $meta);
  my $e;
  my $partnum = $filename;
  $partnum =~ s!^parts/!!;
  $partnum =~ s!\.dat$!!;
  
  try {
    ($obj, $meta) = ldraw_to_obj($filename, $colorinfo);
  } catch {
    open my $error_fh, ">", "$partnum.txt" or die "Can't open $partnum.txt: $!";
    print $error_fh "$_\n";
    #$prog->message("$_\n");
    print "$_\n";
    $e++;
  };
  next if $e;
  if ($obj and $meta->{minifig_slot}) {
    my $kind = $meta->{minifig_slot};

    my $partnum = $filename;
    $partnum =~ s!^parts/!!;
    $partnum =~ s!\.dat$!!;

    my $obj_name  = "../src/main/resources/assets/minifigcraft/models/$kind/$partnum.obj";
    open my $obj_fh, ">:raw", $obj_name;
    print $obj_fh $obj;

    my $json_name = "../src/main/resources/assets/minifigcraft/models/$kind/$partnum.json";
    open my $json_fh, ">:utf8", $json_name;
    print $json_fh encode_json($meta);
  }
  Dump $meta;
  #$next_up = $prog->update($count)
  #  if ++$count >= $next_up;
}


sub usage {
    say "LDraw .dat file to .STL file converter";
    say "======================================";
    say "theorbtwo - Jan 2011";
    say "Usage: $0 someldrawfile.dat > outputfile.stl";
}

sub ceil {
  Math::Round::nhimult(1, shift);
}

sub read_colors {
  my ($filename) = @_;
  my $colorinfo = [];
  open my $fh, "<", $filename or die "Can't open $filename: $!";
  $/="\n";
  
  while (<$fh>) {
    chomp;
    if ($_ =~ m/^0 LDraw\.org/ or
        $_ =~ m/^0 (Name|Author): / or
        $_ =~ m/^0 !LDRAW_ORG Configuration UPDATE/ or
        $_ eq '' or
        $_ =~ m!^0\s*//! or
        $_ eq '0'
       ) {
      # Comment
    } elsif ($_ =~ m/^0 !COLOU?R\s+(?<name>.*?)\s+CODE\s+(?<code>\d+)\s+VALUE\s+#(?<value>[0-9A-Fa-f]+)\s+EDGE\s+#(?<edge>[0-9A-Fa-f]+)(?<extra>.*)$/) {
      my $this_color = {%+};
      $colorinfo->[$this_color->{code}] = $this_color;
      my $extra = delete $this_color->{extra};
      while (length $extra) {
        my $oldlen = length $extra;

        $extra =~ s/^\s+//;
        $extra =~ s/\b(ALPHA|LUMINANCE|FRACTION|VFRACTION|SIZE|MINSIZE|MAXSIZE)\s+([\d.]+)// and $this_color->{lc $1} = $2;
        $extra =~ s/\b(CHROME|METAL|PEARLESCENT|RUBBER)\b// and $this_color->{lc $1} = 1;
        $extra =~ s/\bMATERIAL GLITTER VALUE #([0-9A-Fa-f]+)\b// and $this_color->{glitter_value} = $2;
        $extra =~ s/\bMATERIAL SPECKLE VALUE #([0-9A-Fa-f]+)\b// and $this_color->{speckle_value} = $2;

        if (length($extra) == $oldlen) {
          die "Don't know what to do with (rest of) extra: $extra";
        }
      }
      $this_color->{alpha} //= 255;
    } else {
      die "Don't know what to do with .ldr declaration '$_' at $filename line $.";
    }
  }

  # Right.  Read the colour info out of the file, lets put it into a texture file.
  my $map_size = ceil(sqrt(@$colorinfo));
  my $img = Imager->new(xsize=>$map_size,
                        ysize=>$map_size,
                        channels => 4);
  for my $code (0..@$colorinfo-1) {
    my $info = $colorinfo->[$code];
    my $x = int($code/$map_size);
    my $y = $code % $map_size;
    # For now, at least, we let the other material properties be ignored.
    my $img_color;
    if (defined $info) {
      $img_color = Imager::Color->new(web => $info->{value}, alpha => $info->{alpha});
    } else {
      $img_color = Imager::Color->new(web => '#ff00ff', alpha => 255);
    }
    $img->setpixel(x=>$x, y=>$y, color=>$img_color);
    $info->{x} = $x;
    $info->{y} = $y;
    $info->{tex_x} = sprintf "%.4f", $x/$map_size;
    $info->{tex_y} = sprintf "%.4f", $y/$map_size;
  }

  # Dump $colorinfo;
  
  return ($colorinfo, $img);
}

sub ldraw_to_obj {
  my ($dat_filename, $color_info) = @_;
  
  # Each stack entry has...
  # {filename}: Filename that this represents.
  # {color}: The color being drawn (ldraw color number)
  # {effective_matrix}: A Math::MatrixReal, 4x4, the matrix that should be (post) multiplied to give
  #  ... err, more verbiage goes here.
  # {bfc}{certified}: Set to 1 by top-level
  # {bfc}{winding}: Either cw or ccw
  # {bfc}{invertnext}: 1 when an 0 BFC INVERTNEXT command is in effect -- that is, we are looking for the "next".
  # {bfc}{inverting}: 1 when we are inverting -- the parent had an invertnext in effect.
  my @stack;
  ## current item on stack (bottom of stack)
  my $bos = {
            };
  $bos->{filename} = $dat_filename;
  $bos->{color} = 0;
  
  # Minecraft's eye-point is 1.62m (above bottom of feet).
  # An actual minifig's eye-point is 35mm.
  my $s = 1.62 * 0.4/35;
  
  # We need to specify the correct initial matrix here to:
  # http://www.ldraw.org/Article218.html#coords
  # 1: Scale from LDU to mm.  1 ldu = 0.4 mm
  # 2: Rotate 90 degrees about x.  Ldraw's coord sys has -y as up, reprap's uses +z is up.
  # ldraw:     1 ldu = 0.4mm, -y is up, origin for helmet is bottom of inside stud.
  # reprap:    1 mm, +z is up
  # minecraft: 1 m(?), +y is up.
  #     0 is feet
  #     1.62 is eye-point, 
  #     1.85 is top of head (inference from eye height)...
  #     1.80 is top of head (AABB).  Width=0.6m
  $bos->{effective_matrix} = Math::MatrixReal->new_from_rows([[ $s,   0,   0,  0],
                                                              [  0,  $s,   0,  0],
                                                              [  0,   0,  $s,  0],
                                                              [  0,   0,   0,  1]]
                                                            );
  
  $stack[0] = $bos;
  
  my @model_data;
  my $meta;
  
  while (@stack) {
    if (!$bos->{fh}) {
      $bos->{fh} = open_ldraw_file($bos->{filename});
      $bos->{filename} = find_ldraw_file($bos->{filename});
    }
    
    if (eof $bos->{fh}) {
      pop @stack;
      $bos = $stack[-1];
      next;
    }
    
    my $line = readline($bos->{fh});
    if (not defined $line) {
      die "Can't read line from $bos->{filename}: $!";
    }
    chomp $line;
    $line =~ s/\x0d//g;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    
    #warn "$bos->{filename} $.: <<$line>>\n";

    if ($line =~ m/^0\s/ || $line =~ m/^0$/) {
      
      if ($line =~ m/^0 BFC (.*)$/) {
        # http://webcache.googleusercontent.com/search?q=cache:3Ba0lniZ724J:www.ldraw.org/Article415.html&cd=1&hl=en&ct=clnk
        
        my @flags = map {lc} split /\s+/, $1;
        
        for (@flags) {
          my $act = {'certify' => sub { $bos->{bfc}{certified} = 1;},
                     'nocertify' => sub { $bos->{bfc}{certified} = 0;},
                     'ccw'      => sub { $bos->{bfc}{winding} = 'ccw'; },
                     'cw'       => sub { $bos->{bfc}{winding} = 'cw'; },
                     'invertnext' => sub { $bos->{bfc}{invertnext} = 1; },
                     'noclip' => sub {
                       # NOCLIP is fundementally impossible for us to implement, since we don't actually control clipping, the renderer does.
                       # This does mean that, eg, 2507p01.dat = 0 Windscreen 10 x  4 x  2.333 Canopy with Silver Frame Pattern
                       # may be misrendered (the sticker will appear only when viewed from one side).
                     },
                     'clip' => sub {
                       # This just takes us back to the default that noclip took us out of.  Since we don't do anything there, there is nothing to undo here.
                     },
                    }->{$_};
          if ($act) {
            $act->();
          } else {
            $|=1;
            die "Unhandled flag $_ in BFC line at $bos->{filename} line $.";
          }
        }
      } elsif ($line =~ m/^0 ([^!].*)/ and not $meta->{firstline_name}) {
        $meta->{firstline_name} = $1;
      } elsif ($line =~ m/^0 (Name):\s*(.*)/) {
        $meta->{lc $1} ||= $2;
      } elsif ($line =~ m/^0 (Author):\s*(.*)/) {
        # We can't check if ldraw_type is Primitive, because author is before ldraw_type in the files.
        #if (($bos->{ldraw_type}//'') ne 'Primitive') {
        #  $meta->{lc $1}{$2}++;
        #}
        my ($tag, $value) = ($1, $2);
        if ($bos->{filename} =~ m!^parts/!) {
          $meta->{lc $tag}{$value}++;
        } else {
          #print "ignoring author in ".$bos->{filename}."\n";
        }
      } elsif ($line =~ m/^0 !KEYWORDS\s*(.*)/) {
        my @words = map {lc} split /,\s*/, $1;
        $meta->{keywords}{$_}++ for @words;
      } elsif ($line =~ m/^0 !CATEGORY\s*(.*)/) {
        $meta->{keywords}{lc $1}++ 
      } elsif ($line =~ m/^0 !LDRAW_ORG ([\w ]+) (UPDATE|ORIGINAL)/) {
        $meta->{ldraw_type} //= $1;
        $bos->{ldraw_type} = $1;
      } elsif ($line =~ m/^0 !LICENSE (.*)/) {
        if ($1 ne 'Redistributable under CCAL version 2.0 : see CAreadme.txt') {
          die "Unknown license $1 at $bos->{filename} line $.";
        }
      } elsif ($line =~ m/^0 !CMDLINE -[cC](\d+)/) {
        $bos->{color} = resolve_color($bos->{color}, $1);
      } elsif ($line eq '0' or
               $line =~ m!^0\s+//! or
               $line =~ m/^0 !HELP/) {
        # actual comments
      } elsif ($line =~ m/^0 !HISTORY/) {
        # Don't care
      } elsif (@stack > 1) {
        # We don't care huge amounts about metadata in sub-files.
      } elsif ($bos->{post_header}) {
        # ...or huge amounts about zero lines that happen after we already have geometry.
      } else {
        die "Don't know what to do with 0 line '$line' at $bos->{filename} line $.";
      }
      
      # FIXME: Hoist up to a configuration thingy?
      # Skip general non-minifig parts
      if ($meta->{firstline_name} =~ m/^Sticker|Baseplate|Container|Electric|Rock|Technic (?:Axle|Angle|Shock|Gear)|Tile|Plate|Animal|Antenna|Duplo|Brick|Car|Bracket/) {
        return;
      }

      # Skip aliases
      if ($meta->{firstline_name} =~ m/^[~=]/) {
        return;
      }
      if ($meta->{ldraw_type} and $meta->{ldraw_type} eq 'Part Alias') {
        return;
      }

      # Don't skip shortcuts, we want helmet-with-visor shortcuts.
      #if ($meta->{ldraw_type} and $meta->{ldraw_type} eq 'Shortcut') {
      #  return;
      #}

      if ($meta->{firstline_name} =~ m/Minifig (Hair|Helmet|Headdress) /) {
        $meta->{minifig_slot} = 'helmet';
      }
      if ($meta->{firstline_name} =~ m/Minifig Beard / or
          $meta->{keywords}{'minifig neckwear'}) {
        $meta->{minifig_slot} = 'neck';
      }
      if ($meta->{firstline_name} =~ m/Minifig (Shield|Sword)/) {
        $meta->{category}{jmm_minifig_slot_hand}++;
        $meta->{minifig_slot} = 'hand';
        return;
      }

    } elsif ($line =~ m/^\s*$/) {
    } elsif ($line =~ m/^1\s/) {
      $bos->{post_header} = 1;
      # Math::MatrixReal doesn't like floats without a leading zero.
      $line =~ s/ (-?)\./ ${1}0./g;
      my @split = split m/\s+/, $line;
      my (undef, $color, $x, $y, $z) = splice(@split, 0, 5);
      my @xforms = splice(@split, 0, 9);
      my $file = shift @split;
      if (@split) {
        die "Too many values on type 1 line $line -- @split  at $bos->{filename} line $.";
      }
      
      my $new_xform =
        Math::MatrixReal->new_from_rows([[$xforms[0], $xforms[1], $xforms[2], $x],
                                         [$xforms[3], $xforms[4], $xforms[5], $y],
                                         [$xforms[6], $xforms[7], $xforms[8], $z],
                                         [0,          0,          0,          1 ]]);
      
      my $old_bos = $bos;
      
      push @stack, {};
      $bos = $stack[-1];
      $bos->{filename} = $file;
      $bos->{color} = resolve_color($old_bos, $color);
      $bos->{effective_matrix} = $old_bos->{effective_matrix} * $new_xform;
      
      $bos->{bfc}{inverting} = $old_bos->{bfc}{inverting};
      #warn "Inverting starts at $bos->{bfc}{inverting}\n";
      
      $bos->{bfc}{inverting} = !$bos->{bfc}{inverting}
        if $old_bos->{bfc}{invertnext};
      #warn "Inverting after checking invertnext: $bos->{bfc}{inverting}\n";
      
      #warn "Determinant: ", $new_xform->det, "\n";
      $bos->{bfc}{inverting} = !$bos->{bfc}{inverting}
        if $new_xform->det < 0;
      #warn "Inversion after checking det: $bos->{bfc}{inverting}\n";
      
      #print STDERR Dumper($old_bos);
      #print STDERR Dumper($bos);
      
      $old_bos->{bfc}{invertnext} = 0;
    } elsif ($line =~ m/^2/) {
      $bos->{post_header} = 1;
      # We do not implement type 2 lines, which are line segments, and
      # thus have zero width and cannot exist in the real world.
      
    } elsif ($line =~ m/^3\s/) {
      $bos->{post_header} = 1;
      my ($color, @points) = extract_polygon(3, $line, $bos);
      $color = resolve_color($bos, $color);
      
      push @model_data, {type => 'triangle',
                         points => [map {apply_xform($bos->{effective_matrix}, $_)} @points],
                         color => $color};
      
    } elsif ($line =~ m/^4\s/) {
      $bos->{post_header} = 1;
      my ($color, @points) = extract_polygon(4, $line, $bos);
      
      $color = resolve_color($bos, $color);
      
      @points = map {apply_xform($bos->{effective_matrix}, $_)} @points;
      
      #push @model_data, {type => 'quad', points => \@points, color=>$color};
      
      # Decompose the quad into two triangles *with the same winding as the original quad*
      # so the output loop only has to deal with triangles, not quads.
      
      push @model_data, {type => 'triangle',
                         points => [$points[0], $points[1], $points[3]],
                         color => $color
                        };
      
      push @model_data, {type => 'triangle',
                         points => [$points[1], $points[2], $points[3]],
                         color => $color
                        };
      
    } elsif ($line =~ m/^5\s/) {
      $bos->{post_header} = 1;
      # Type 5 lines are optinal line segments, and are unimplemented for the same reason as type 2.
    } else {
      die "Unhandled line $line from $bos->{filename}:$.";
    }
  }
  
  #print "<finished>\n";
  #Dump \@model_data;
  
  my %vertex_knowns;
  my $next_vertex_n = 1;

  my %tc_knowns;
  my $next_tc_n = 1;
  
  my $obj;
  
  for my $facet (@model_data) {
    my @vertex_strings;
    my $ci = $facet->{color};
    my $tc_short = sprintf "%s %s", $ci->{tex_x}, $ci->{tex_y};
    my $tc_n;
    if ($tc_knowns{$tc_short}) {
      $tc_n = $tc_knowns{$tc_short};
    } else {
      $tc_n = $next_tc_n++;
      $tc_knowns{$tc_short} = $tc_n;
      $obj .= "vt $tc_short\n";
    }
    for my $vertex (@{$facet->{points}}) {
      my $n;
      # Forge's WavefrontObject seems a bit over-specific about the format of "v" lines:
      # private static Pattern vertexPattern = Pattern.compile("(v( (\\-){0,1}\\d+\\.\\d+){3,4} *\\n)|(v( (\\-){0,1}\\d+\\.\\d+){3,4} *$)");
      # (v( (\\-){0,1}\\d+\\.\\d+){3,4} *\\n)|(v( (\\-){0,1}\\d+\\.\\d+){3,4} *$)
      # (v( (\-){0,1}\d+\.\d+){3,4} *\n)|(v( (\-){0,1}\d+\.\d+){3,4} *$)
      # (v( (-){0,1}\d+\.\d+){3,4} *\n)|(v( (\-)?\d+\.\d+){3,4} *$)
      # There must be a dot in every number, and at least one digit both before and after it.  (Even if the coord happens to be an integer.)
      my $short = join ' ', map {sprintf "%.4f", $_} @$vertex;
      if ($vertex_knowns{$short}) {
        $n = $vertex_knowns{$short};
      } else {
        $n = $next_vertex_n++;
        $vertex_knowns{$short} = $n;
        $obj .= "v $short\n";
      }
      push @vertex_strings, "$n/$tc_n";
    }
    $obj .= sprintf "f %s\n", join(" ", @vertex_strings);
  }
  return ($obj, $meta);
}

sub apply_xform {
  my ($xform, $point) = @_;
  # The $_+0 bit is to convert things of the form .333 (no leading zero), which Math::MatrixReal chokes on.
  my $xformed = $xform * Math::MatrixReal->new_from_cols([[map {$_+0} @$point, 1]]);
  
  return [$xformed->element(1,1),
          $xformed->element(2,1),
          $xformed->element(3,1),
         ];
}

sub extract_polygon {
  my ($size, $line, $bos) = @_;

  # parts/s/2528s01.dat line 385
  #   color
  #      x1      y1        z1  x2 y2 z2  x3     y3       z3   x4      y4       z4
  # 3 16 16.3651 -0.134918 2   18 -1 2   16.382 -4.12189 2    11.9744 -8.33964 2
  my @split = split m/\s+/, $line;
  shift @split;
  my $color = shift @split;
  my @points;
  $points[$_] = [splice @split, 0, 3] for 0..$size-1;
  if (@split) {
    print "Too many arguments to type 3 line <<$line>> -- @split remain at $bos->{filename} line $.\n";
  }
  
  if ($bos->{bfc}{inverting}) {
    @points = reverse @points;
  }

  $bos->{bfc}{winding} //= 'ccw';
  if ($bos->{bfc}{winding} eq 'cw') {
    @points = reverse @points;
  } elsif ($bos->{bfc}{winding} eq 'ccw') {
    # No need to do anything
  } else {
    die "Winding neither cw nor ccw: $bos->{bfc}{winding}  at $bos->{filename} line $.";
  }
  
  return ($color, @points);
  
  #    push @model_data, {type => 'triangle',
  #                      points => [map {apply_xform($bos->{effective_matrix}, $_)} @points],
  #                       color => $color};
}

sub resolve_color {
  my ($stackitem, $color) = @_;
  if ($color =~ m!^0x!) {
    # FIXME: 0x2rrGGbb, how do we do this nicely ?
    return $stackitem->{color};
  } elsif ($color == 16) {
    return $stackitem->{color};
  } elsif ($color == 24) {
    die "Get edge color for color #$stackitem->{color} at ??? line $.";
  }
  my $ci = $colorinfo->[$color];
  if (!$ci) {
    die "Resolved color $color, but no colorinfo for that color?";
  }
  return $ci;
}

my %cache;
sub find_ldraw_file {
  my ($short_name) = @_;
  $short_name = lc $short_name;
  
  my $fh;

  $short_name =~ s!\\!/!g;

  if ($cache{$short_name}) {
    return $cache{$short_name};
  }
  if (-e $short_name) {
    $cache{$short_name} = $short_name;
    return $short_name;
  }
  for my $prefix ('parts', 'p') {
    my $name = "$prefix/$short_name";
    #print "Checking $name\n";
    if (-e $name) {
      $cache{$short_name} = $name;
      return $name;
    }
  }

  die "can't find $short_name anywhere at ??? line $.";
}

sub open_ldraw_file {
  my ($filename) = @_;
  $filename = find_ldraw_file($filename);

  open my $fh, '<', $filename or die "Can't open $filename: $!";
  return $fh;
}

__END__

=head1 NAME

ldraw2stl - an LDraw.dat file to .stl 3d object model converter

=head1 SYNOPSIS

    git clone https://github.com/theorbtwo/reprapstuff.git
    cd lego

    # Visit http://ldraw.org/Downloads.html
    # Download the "LDraw Parts Library" from the "Core files and libraries" section
    # mkdir ldraw
    # cd ldraw
    # Unpack the zip file into the ldraw directory
    # Visit http://peeron.com to find a partnumber to convert.

    perl ldraw2stl.pl 1234.dat > 1234.stl

=head1 DESCRIPTION

LDraw is a piece of design software specifically for modelling Lego
parts, which uses it's own storage format. The format is well
specified on the ldraw website.

STL is a commonly used 3D modelling format, used for 3D printers,
among other things.

This perl script converts LDraw .dat files representing Lego pieces,
into the equivalent STL model code.

=head1 AUTHOR

James Mastros <james@mastros.biz>



    
