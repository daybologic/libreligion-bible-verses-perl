# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Religion::Bible::Verses::Base;
use Moose;

use Religion::Bible::Verses::DI::Container;

use DateTime;
use DateTime::Format::Strptime;
use English qw(-no_match_vars);
use Scalar::Util qw(blessed);

# TODO: Do we need a trap to ensure a fatal error occurs if the dic is constructed more than once?
has dic => (isa => 'Religion::Bible::Verses::DI::Container', is => 'rw', lazy => 1, default => \&__makeDIContainer);

sub __makeDIContainer {
	my ($self) = @_;
	return Religion::Bible::Verses::DI::Container->new();
}

sub __resolveISO8601 {
	my ($self, $iso8601) = @_;

	$iso8601 ||= DateTime->now; # The default is the current time
	if (my $ref = blessed($iso8601)) {
		if ($ref->isa('DateTime')) {
			return $iso8601;
		} else {
			die('Unsupported blessed time format');
		}
	}

	my $format = DateTime::Format::Strptime->new(pattern => '%FT%T%z');
	eval {
		$iso8601 = $format->parse_datetime($iso8601);
	};

	if (my $evalError = $EVAL_ERROR) {
		die('Unsupported ISO-8601 time format: ' . $evalError);
	}

	return $iso8601;
}

1;
