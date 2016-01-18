use strict;
use warnings;

use lib 't/lib';

use IPC::Run3 qw(run3);
use Path::Class;
use Path::Class::Rule;

use Test::More 0.98;
use Test::Differences;

my %todo = (
    'test-name-matches-file' => 1,
);

test_formatter($_) for <t/test-data/basic/*>;
test_formatter('t/test-data/basic');
test_formatter( 't/test-data/basic', q{ in parallel} );

done_testing;

sub test_formatter {
    my $test_dir    = shift;
    my $is_parallel = shift;

    local $TODO = 'This is a known bug'
        if $todo{ dir($test_dir)->basename };

    subtest(
        $test_dir . ( $is_parallel // q{} ),
        sub {

            my @t_files
                = Path::Class::Rule->new->file->name(qr/\.st/)
                ->all($test_dir);

            @t_files = grep { !$todo{ $_->dir->basename } } @t_files
                if @t_files > 1;

            my @prove
                = qw( prove --lib --merge --verbose --formatter TAP::Formatter::TeamCity );
            push @prove, qw( -j 2 ) if $is_parallel;

            my ( @stdout, $stderr );
            run3(
                [ @prove, @t_files ],
                \undef,
                \@stdout,
                \$stderr,
            );

            if ($stderr) {
                fail('got unexpected stderr');
                diag($stderr);
            }

            # we don't want to compare the test summary, but it has a different number
            # of lines depending on $is_ok so we just stop collecting lines once we
            # hit something that looks like that summary.
            my @output;
            for my $l (@stdout) {
                last
                    if $l =~ /Parse errors:/
                    || $l =~ /^Files=\d+/
                    || $l =~ /^Test Summary Report/
                    || $l =~ /^All tests successful\./;

                push @output, _remove_timestamp($l);
            }

            my $actual = join q{}, @output;

            if ($is_parallel) {
                _test_parallel_output( \@t_files, $actual );
            }
            else {
                _test_sequential_output( \@t_files, $actual );
            }
        }
    );
}

sub _remove_timestamp {
    my $line = shift;

    # We only touch TC message lines that include name/value pairs
    return $line unless $line =~ /^\Q##teamcity[\E[^ ]+ [^=]+='[^']*'/;

    my $ok = ok(
        $line =~ s/ timestamp='([^']+)'//,
        'teamcity directive line has a timestamp'
    ) or diag($line);

    if ($ok) {
        my $ts = $1;
        like(
            $ts,
            qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/,
            'timestamp matches expected format'
        );
    }

    return $line;
}

sub _test_parallel_output {
    my $t_files = shift;
    my $actual  = shift;

    # Lines of the form '# ...' are stderr output from the tests. With a
    # parallel run, the order these come in is not entirely predictable so we
    # filter them out. As long as we got the TeamCity build messages we
    # expected, we should be good.
    $actual =~ s/^ \#\ .+ $ \n//xmg;

    for my $t_file ( @{$t_files} ) {
        my $expected_lines_re = join "\n",
            map  { qr/ ^ \Q$_\E $ \n /xm }
            grep { !/ ^ #\ .+ /xm }
            ## no critic (BuiltinFunctions::ProhibitComplexMappings)
            map { chomp; $_ } $t_file->dir->file('expected.txt')->slurp;

        like(
            $actual,
            qr{
                  ^ \#\#\Qteamcity[progressMessage 'starting $t_file']\E $ \n
                  (?: ^ .+ $ \n)*
                  $expected_lines_re
            }xm,
            "output from $t_file"
        );
    }
}

sub _test_sequential_output {
    my $t_files = shift;
    my $actual  = shift;

    my $expected = join q{},
        map { scalar $_->dir->file('expected.txt')->slurp } @{$t_files};

    $_ =~ s{\n+$}{\n} for $actual, $expected;

    _clean_actual( \$actual );
    _clean_expected( \$expected );

    eq_or_diff_text( $actual, $expected, 'actual output vs expected' );
}

sub _clean_actual {
    my $actual = shift;

    # These hacks exist to replace user-specific paths with some sort of fixed
    # test. Long term, it'd be better to test the formatter by feeding it TAP
    # output directly rather than running various test files with the
    # formatter in place.
    ${$actual} =~ s{(#\s+at ).+/Moose([^\s]+) line \d+}{${1}CODE line XXX}g;
    ${$actual} =~ s{\(\@INC contains: .+?\)}{(\@INC contains: XXX)}sg;
}

sub _clean_expected {
    my $expected = shift;

    # The error message for attempting to load a module that doesn't exist was
    # changed in 5.18.0.
    ${$expected}
        =~ s{\Q(you may need to install the SomeNoneExistingModule module) }{}g
        if $] < 5.018;
}
