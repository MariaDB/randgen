#!/usr/bin/env perl
#
# Generate a dataset that ENABLES the MDEV-36205 "subdistance / extrapolation"
# optimization in MariaDB vector search (12.1.1+).
#
# Enabling conditions (from sql/vector_mhnsw.cc, branch bb-12.1-...-subdist):
#   * subdist_part            = 192 floats  -> vectors must have vec_len >= 384
#                               (use_subdist = vec_len >= subdist_part * 2)
#   * subdist_stddev_valid    = 10000       -> need > 10000 collected samples
#   * subdist_stddev_threshold= 0.05        -> stddev(subdist/dist) must be < 0.05
#                               over those samples, then mode becomes STAT_SUBDIST
#
# The optimization estimates the full distance from the first 192 dims:
#     subdist = prefix_sqdist / 192 * vec_len
# For stddev(subdist/dist) to be tiny, the sum of squared differences BEYOND
# dim 192 must be a near-constant fraction of the prefix sum for all pairs.
# Purely random i.i.d. vectors give stddev ~= 0.07-0.10 (feature stays OFF).
#
# This generator produces "Matryoshka-like" vectors:
#   * first PREFIX dims  : unit-variance informative content
#   * remaining dims     : low-energy tail (variance = TAIL_EPS**2)
# so the tail is a small, consistent correction -> stddev(subdist/dist) << 0.05.

use strict;
use warnings;
use Getopt::Long;
use POSIX qw(floor);

use constant PREFIX => 192;          # must equal subdist_part
use constant TWO_PI => 8 * atan2(1, 1);

# Standard normal via Box-Muller.
sub gauss {
    my ($mean, $sd) = @_;
    my $u1 = rand();
    $u1 = 1e-12 if $u1 < 1e-12;      # avoid log(0)
    my $u2 = rand();
    return $mean + $sd * sqrt(-2 * log($u1)) * cos(TWO_PI * $u2);
}

sub gen_vector {
    my ($dim, $tail_eps) = @_;
    my @v;
    for my $i (0 .. $dim - 1) {
        push @v, ($i < PREFIX ? gauss(0.0, 1.0) : gauss(0.0, $tail_eps));
    }
    return \@v;
}

sub to_hex {
    # little-endian float32, matches x'..' literals in vector.test
    my ($vec) = @_;
    return unpack('H*', pack('f<*', @$vec));
}

sub to_text {
    my ($vec) = @_;
    return '[' . join(',', map { sprintf('%.6f', $_) } @$vec) . ']';
}

# ----- options ------------------------------------------------------------
my %opt = (
    rows     => 20000,   # >= a few thousand to exceed 10000 distance samples
    dim      => 768,     # must be >= 384
    tail_eps => 0.05,    # stddev of low-energy tail (smaller = surer enable)
    queries  => 200,     # KNN queries appended at the end
    batch    => 500,     # rows per INSERT statement
    seed     => 42,
    format   => 'hex',   # 'hex' or 'text'
    out      => '/data/bug/mdev36205_dataset.sql',
);

GetOptions(
    'rows=i'     => \$opt{rows},
    'dim=i'      => \$opt{dim},
    'tail-eps=f' => \$opt{tail_eps},
    'queries=i'  => \$opt{queries},
    'batch=i'    => \$opt{batch},
    'seed=i'     => \$opt{seed},
    'format=s'   => \$opt{format},
    'out=s'      => \$opt{out},
) or die "Invalid options\n";

die "dim must be >= 384 (subdist_part*2)\n" if $opt{dim} < PREFIX * 2;
die "format must be 'hex' or 'text'\n" if $opt{format} !~ /^(hex|text)$/;

srand($opt{seed});

sub lit {
    my ($vec) = @_;
    return $opt{format} eq 'hex'
        ? "x'" . to_hex($vec) . "'"
        : "vec_fromtext('" . to_text($vec) . "')";
}

# ----- emit ---------------------------------------------------------------

print STDERR "# MDEV-36205 subdistance/extrapolation enabling dataset\n";
printf STDERR "# dim=%d rows=%d tail_eps=%g\n",
    $opt{dim}, $opt{rows}, $opt{tail_eps};
print "CREATE DATABASE IF NOT EXISTS vector_db;\n";
print "USE vector_db;\n";
print "DROP TABLE IF EXISTS vec_subdist;\n";
printf "CREATE TABLE vec_subdist (\n"
    . "  id INT AUTO_INCREMENT PRIMARY KEY,\n"
    . "  v VECTOR(%d) NOT NULL,\n"
    . "  VECTOR (v)\n"
    . ");\n", $opt{dim};

my @buf;
for my $i (0 .. $opt{rows} - 1) {
    push @buf, '(' . lit(gen_vector($opt{dim}, $opt{tail_eps})) . ')';
    if (@buf == $opt{batch} || $i == $opt{rows} - 1) {
        print "INSERT INTO vec_subdist (v) VALUES\n";
        print join(",\n", @buf);
        print ";\n";
        @buf = ();
    }
}

# Queries to accumulate/confirm subdist samples on the search path.
# for (1 .. $opt{queries}) {
#    my $q = gen_vector($opt{dim}, $opt{tail_eps});
#    printf "SELECT id FROM vec_subdist "
#        . "ORDER BY VEC_DISTANCE_EUCLIDEAN(v, %s) LIMIT 10;\n", lit($q);
#}

printf STDERR "wrote %s (%d rows, dim=%d)\n", $opt{out}, $opt{rows}, $opt{dim};
