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

if(!$ARGV[0] || !-e $ARGV[0]) {
    usage();
    exit;
  }
my ($colorinfo, $img) = read_colors('LDConfig.ldr');
$img->write(file=>'ldraw_texture.png');

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
  open my $fh, "<", $filename;
  while (<>) {
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

  Dump $colorinfo;
  
  return ($colorinfo, $img);
}

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
$bos->{filename} = $ARGV[0];
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

while (@stack) {
  if (!$bos->{fh}) {
    $bos->{fh} = open_ldraw_file($bos->{filename});
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
                   'ccw'      => sub { $bos->{bfc}{winding} = 'ccw'; },
                   'cw'       => sub { $bos->{bfc}{winding} = 'cw'; },
                   'invertnext' => sub { $bos->{bfc}{invertnext} = 1; },
                  }->{$_};
        if ($act) {
          $act->();
        } else {
          $|=1;
          die "Unhandled flag $_ in BFC line";
        }
      }
    } else {
      # Not a BFC line.
      # print "$line\n";
    }

  } elsif ($line =~ m/^\s*$/) {
  } elsif ($line =~ m/^1\s/) {
    my @split = split m/\s+/, $line;
    my (undef, $color, $x, $y, $z) = splice(@split, 0, 5);
    my @xforms = splice(@split, 0, 9);
    my $file = shift @split;
    if (@split) {
      die "Too many values on type 1 line $line -- @split";
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
    # We do not implement type 2 lines, which are line segments, and
    # thus have zero width and cannot exist in the real world.

  } elsif ($line =~ m/^3\s/) {
    my ($color, @points) = extract_polygon(3, $line, $bos);
    $color = resolve_color($bos, $color);

    push @model_data, {type => 'triangle',
                       points => [map {apply_xform($bos->{effective_matrix}, $_)} @points],
                       color => $color};

  } elsif ($line =~ m/^4\s/) {
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
    # Type 5 lines are optinal line segments, and are unimplemented for the same reason as type 2.
  } else {
    die "Unhandled line $line from $bos->{filename}:$.";
  }
}

#print "<finished>\n";
#Dump \@model_data;

my %vertex_knowns;
my $next_vertex_n = 1;

for my $facet (@model_data) {
  my @vertex_nums;
  my $color = $facet->{color};
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
      print "v $short\n";
    }
    push @vertex_nums, $n;
  }
  print "f ", join(" ", @vertex_nums), "\n";
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
  
  my @split = split m/\s+/, $line;
  shift @split;
  my $color = shift @split;
  my @points;
  $points[$_] = [splice @split, 0, 3] for 0..$size-1;
  if (@split) {
    die "Too many arguments to type 3 line <<$line>> -- @split remain";
  }
  
  if ($bos->{bfc}{inverting}) {
    @points = reverse @points;
  }
  
  if ($bos->{bfc}{winding} eq 'cw') {
    @points = reverse @points;
  } elsif ($bos->{bfc}{winding} eq 'ccw') {
    # No need to do anything
  } else {
    die "Winding neither cw nor ccw: $bos->{bfc}{winding}";
  }
  
  return ($color, @points);
  
  #    push @model_data, {type => 'triangle',
  #                      points => [map {apply_xform($bos->{effective_matrix}, $_)} @points],
  #                       color => $color};
}

sub resolve_color {
  my ($stackitem, $color) = @_;
  if ($color == 16) {
    return $stackitem->{color};
  }
  if ($color == 24) {
    die "Get edge color for color #$stackitem->{color}";
  }
  return $color;
}

my %cache;
sub find_ldraw_file {
  my ($short_name) = @_;

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

  die "can't find $short_name anywhere";
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



    
