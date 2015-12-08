package TAP::Formatter::TeamCity;

use 5.010;

use strict;
use warnings;

our $VERSION = '0.050';

use TAP::Formatter::Session::TeamCity;

use base qw(TAP::Formatter::Base);

sub open_test {
    my $self      = shift;
    my $test_name = shift;
    my $parser    = shift;

    my $session = TAP::Formatter::Session::TeamCity->new(
        {
            name      => $test_name,
            formatter => $self,
            parser    => $parser,
        }
    );

    return $session;
}

1;

# ABSTRACT: Emit test results as TeamCity build messages

__END__

=pod

=head1 SYNOPSIS

   # When using prove(1):
   prove --merge --formatter TAP::Formatter::TeamCity my_test.t

=head1 DESCRIPTION

L<TAP::Formatter::TeamCity> is a formatter for L<TAP::Harness> that emits
TeamCity build messages to the console, rather than the usual output. The
TeamCity build server is able to process these messages in the build log and
present your test results in its web interface (along with some nice
statistics and graphs).

=head1 SUGGESTED USAGE

The TeamCity service messages are generally not human-readable, so you
probably only want to use this Formatter when the tests are being run by a
TeamCity build agent and the L<TAP::Formatter::TeamCity> module is available.

=head1 LIMITATIONS

TeamCity comes from a jUnit culture, so it doesn't understand skip and TODO
tests in the same way that Perl testing harnesses do. Therefore, this
formatter simply treats skipped and TODO tests as ignored tests.

=head1 SEE ALSO

L<TeamCity::BuildMessages>

=cut
