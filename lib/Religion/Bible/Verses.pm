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

package Religion::Bible::Verses;
use strict;
use warnings;
use Moose;

extends 'Religion::Bible::Verses::Base';

use Data::Dumper;
use Digest::CRC qw(crc32);
use Scalar::Util qw(looks_like_number);

use Religion::Bible::Verses::Backend;
use Religion::Bible::Verses::DI::Container;
use Religion::Bible::Verses::Search::Query;
use Religion::Bible::Verses::Verse;

has __backend => (is => 'ro', isa => 'Religion::Bible::Verses::Backend', lazy => 1, default => \&__makeBackend);

has bookCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeBookCount);

has books => (is => 'ro', isa => 'ArrayRef[Religion::Bible::Verses::Book]', lazy => 1, default => \&__makeBooks);

BEGIN {
	our $VERSION = '0.5.0';
}

sub BUILD {
}

sub getBookByShortName {
	my ($self, $shortName, $unfatal) = @_;

	$shortName ||= '';
	$shortName = "\u$shortName";

	foreach my $book (@{ $self->books }) {
		next if ($book->shortName ne $shortName);
		return $book;
	}

	die("Short book name '$shortName' is not a book in the bible") unless ($unfatal);
	return undef;
}

sub getBookByLongName {
	my ($self, $longName) = @_;

	$longName ||= '';
	foreach my $book (@{ $self->books }) {
		next if ($book->longName ne $longName);
		return $book;
	}

	die("Long book name '$longName' is not a book in the bible");
}

sub getBookByOrdinal {
	my ($self, $ordinal) = @_;

	if ($ordinal > $self->bookCount) {
		die(sprintf('Book ordinal %d out of range, there are %d books in the bible',
		    $ordinal, $self->bookCount));
	}

	return $self->books->[$ordinal - 1];
}

sub newSearchQuery {
	my ($self, @args) = @_;

	my %defaults = ( _library => $self );

	return Religion::Bible::Verses::Search::Query->new({ %defaults, text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	return Religion::Bible::Verses::Search::Query->new({ %defaults, %params });
}

sub resolveBook {
	my ($self, $book) = @_;

	unless (blessed($book)) {
		if (looks_like_number($book)) {
			$book = $self->getBookByOrdinal($book);
		} else {
			if (my $shortBook = $self->getBookByShortName($book, 1)) {
				return $shortBook;
			} else {
				$book = $self->getBookByLongName($book);
			}
		}
	}

	return $book;
}

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal) = @_;

	$book = $self->resolveBook($book);
	my $chapter = $book->getChapterByOrdinal($chapterOrdinal);
	my $verse = $chapter->getVerseByOrdinal($verseOrdinal);

	$self->dic->logger->debug($verse->toString());

	return $verse;
}

sub votd {
	my ($self, $when) = @_;

	$when = $self->__resolveISO8601($when);
	$when = $when->set_time_zone('UTC')->truncate(to => 'day');

	my $seed = crc32($when->epoch);
	$self->dic->logger->debug(sprintf('Looking up VoTD for %s', $when->ymd));
	$self->dic->logger->trace(sprintf('Using seed %d', $seed));

	my $bookOrdinal = 1 + ($seed % $self->bookCount);
	my $book = $self->getBookByOrdinal($bookOrdinal);

	my $chapterOrdinal = 1 + ($seed % $book->chapterCount);
	my $chapter = $book->getChapterByOrdinal($chapterOrdinal);

	my $verseOrdinal = 1 + ($seed % $chapter->verseCount);
	my $verse = $chapter->getVerseByOrdinal($verseOrdinal);

	$self->dic->logger->debug($verse->toString());

	return $verse;
}

sub __makeBackend {
	my ($self) = @_;
	return Religion::Bible::Verses::Backend->new({
		_library => $self,
	});
}

sub __makeBookCount {
	my ($self) = @_;
	return scalar(@{ $self->books });
}

sub __makeBooks {
	my ($self) = @_;
	return $self->__backend->getBooks();
}

1;
