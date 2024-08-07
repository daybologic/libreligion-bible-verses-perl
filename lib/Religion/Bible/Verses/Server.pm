#!/usr/bin/perl
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

package Religion::Bible::Verses::Server;
use strict;
use warnings;
use JSON;
use Religion::Bible::Verses;
use UUID::Tiny ':std';

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub __json {
	my ($self) = @_;
	$self->{__json} ||= JSON->new();
	return $self->{__json};
}

sub __bible {
	my ($self) = @_;
	$self->{__bible} ||= Religion::Bible::Verses->new();
	return $self->{__bible};
}

sub __makeJsonApi {
	return (
		data => [ ],
		included => [ ],
		links => { },
	);
}

sub __verseToJsonApi {
	my ($verse) = @_;
	my %hash = __makeJsonApi();

	push(@{ $hash{included} }, {
		type => $verse->chapter->type,
		id => $verse->chapter->id,
		attributes => $verse->chapter->TO_JSON(),
		relationships => {
			book => {
				data => {
					type => $verse->book->type,
					id => $verse->book->id,
				},
			}
		},
	});

	push(@{ $hash{included} }, {
		type => $verse->book->type,
		id => $verse->book->id,
		attributes => $verse->book->TO_JSON(),
		relationships => { },
	});

	push(@{ $hash{data} }, {
		type => $verse->type,
		id => $verse->id,
		attributes => $verse->TO_JSON(),
		relationships => {
			chapter => {
				links => { },
				data => {
					type => $verse->chapter->type,
					id => $verse->chapter->id,
				},
			},
			book => {
				links => { },
				data => {
					type => $verse->book->type,
					id => $verse->book->id,
				},
			},
		},
	});

	return \%hash;
}

sub __lookup {
	my ($self, $params) = @_;
	my $verse = $self->__bible->fetch($params->{book}, $params->{chapter}, $params->{verse});
	return __verseToJsonApi($verse);
}

sub __votd {
	my ($self, $params) = @_;
	my $verse = $self->__bible->votd($params->{when});
	return __verseToJsonApi($verse);
}

sub __search {
	my ($self, $search) = @_;

	my $limit = int($search->{limit});
	$limit ||= 5;

	my $query = $self->__bible->newSearchQuery($search->{term})->setLimit($limit);
	my $results = $query->run();

	my %hash = __makeJsonApi();

	for (my $i = 0; $i < $results->count; $i++) {
		my $verse = $results->verses->[$i];

		my %attributes = ( %{ $verse->TO_JSON() } );
		$attributes{title} = sprintf("Result %d/%d from Chleb Bible Search '%s'", $i+1, $results->count, $search->{term});

		push(@{ $hash{included} }, {
			type => $verse->chapter->type,
			id => $verse->chapter->id,
			attributes => $verse->chapter->TO_JSON(),
			relationships => {
				book => {
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				}
			},
		});

		push(@{ $hash{included} }, {
			type => $verse->book->type,
			id => $verse->book->id,
			attributes => $verse->book->TO_JSON(),
			relationships => { },
		});

		push(@{ $hash{data} }, {
			type => $verse->type,
			id => $verse->id,
			attributes => \%attributes,
			relationships => {
				chapter => {
					links => { },
					data => {
						type => $verse->chapter->type,
						id => $verse->chapter->id,
					},
				},
				book => {
					links => { },
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				},
			},
		});
	}

	push(@{ $hash{included} }, {
		type => 'results_summary',
		id => uuid_to_string(create_uuid()),
		attributes => {
			count => $results->count,
		},
		links => { },
	});

	return \%hash;
}

package main;
use strict;
use warnings;

use Dancer2;
use POSIX qw(EXIT_SUCCESS);

my $server;

set serializer => 'JSON'; # or any other serializer

get '/1/votd' => sub {
	my $when = param('when');
	return $server->__votd({ when => $when });
};

get '/1/lookup/:book/:chapter/:verse' => sub {
	my $book = param('book');
	my $chapter = param('chapter');
	my $verse = param('verse');

	return $server->__lookup({ book => $book, chapter => $chapter, verse => $verse });
};

get '/1/search' => sub {
	my $limit = param('limit');
	my $term = param('term');
	return $server->__search({ limit => $limit, term => $term });
};

unless (caller()) {
	$server = Religion::Bible::Verses::Server->new();
	dance;

	exit(EXIT_SUCCESS);
}

1;
