use strict;

use POSIX qw(ctime);
use XML::DOM;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

package CORBA::XMLSchemas::relaxngVisitor;

# needs $node->{xsd_name} (XsdNameVisitor)

use File::Basename;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser, $standalone, $tag_root) = @_;
	$self->{standalone} = $standalone;
	$self->{tag_root} = $tag_root || "";
	$self->{rng} = 'rng';
#	$self->{corba} = 'corba';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{root} = $parser->YYData->{root};
	my $filename = basename($self->{srcname}, ".idl") . ".rng";
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_inc_rng';
	$self->{need_corba} = undef;
	return $self;
}

sub open_stream {
	my $self = shift;
	my ($filename) = @_;
	open(OUT, "> $filename")
			or die "can't open $filename ($!).\n";
	$self->{out} = \*OUT;
	$self->{filename} = $filename;
}

sub _value {
	my $self = shift;
	my ($node) = @_;

	my $value = $node->{value};
	if (ref $value and $value->isa('Enum')) {
		return $value->{xsd_name};
	} else {
		my $str = $value;
		$str =~ s/^\+//;
		return $str;
	}
}

sub _beautify {
	my $self = shift;
	my ($in) = @_;
	my $out = '';
	my @tab;
	foreach (split /(<[^>']*(?:'[^']*'[^>']*)*>)/, $in) {
		next unless ($_);
		pop @tab if (/^<\//);
		if (/^<\// and $out !~ /\s$/) {
			$out .= "$_\n";
		} elsif (/^</) {
			$out .= join('', @tab) . "$_\n";
		} else {
			$out =~ s/\s+$//;
			$out .= $_;
		}
		push @tab, "  " if (/^<[^\/?!]/ and /[^\/]>$/);
	}
	$out =~ s/\s+$//;
	return $out;
}

sub _no_mapping {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $str = " no mapping for " . $node->{full} . " (" . ref $node . ") ";
	my $comment = $self->{dom_doc}->createComment($str);
	$dom_parent->appendChild($comment);
}

sub _get_defn {
	my $self = shift;
	my ($defn) = @_;
	if (ref $defn) {
		return $defn;
	} else {
		return $self->{symbtab}->Lookup($defn);
	}
}

sub _ref_type {
	my $self = shift;
	my ($type, $dom_parent) = @_;

	if (	   $type->isa('TypeDeclarator')
			or $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType')
			or $type->isa('BaseInterface') ) {
		my $ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
		$ref->setAttribute("name", $type->{xsd_name});
		$dom_parent->appendChild($ref);
	} else {
		my $data = $self->{dom_doc}->createElement($self->{rng} . ":data");
		$data->setAttribute("type", $type->{xsd_name});
		$dom_parent->appendChild($data);

		$type->visit($self, $data);
	}
}

sub _standalone {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	if ($self->{tag_root} eq $node->{xsd_name}) {
		$self->{dom_start} = $self->{dom_doc}->createElement($self->{rng} . ":start");

		my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$self->{dom_start}->appendChild($element);

		my $ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
		$ref->setAttribute("name", $node->{xsd_name});
		$element->appendChild($ref);
	} elsif ($self->{standalone}) {
		my $div = $self->{dom_doc}->createElement($self->{rng} . ":div");
		$dom_parent->appendChild($div);

		my $start = $self->{dom_doc}->createElement($self->{rng} . ":start");
		$start->setAttribute("combine", "choice");
		$div->appendChild($start);

		my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$start->appendChild($element);

		my $ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
		$ref->setAttribute("name", $node->{xsd_name});
		$element->appendChild($ref);
	}
}

#
#	3.5		OMG IDL Specification
#

sub visitSpecification {
	my $self = shift;
	my ($node) = @_;
	my $FH = $self->{out};

	$self->{dom_doc} = new XML::DOM::Document();
	$self->{dom_parent} = $self->{dom_doc};

	my $grammar = $self->{dom_doc}->createElement($self->{rng} . ":grammar");
	$grammar->setAttribute("ns", "http://www.omg.org/IDL-Mapped/");
	$grammar->setAttribute("datatypeLibrary", "http://www.w3.org/2001/XMLSchema-datatypes");
	$grammar->setAttribute("xmlns:" . $self->{rng}, "http://relaxng.org/ns/structure/1.0");
	$self->{dom_parent}->appendChild($grammar);

	if ($self->{root}->{need_corba}) {
		my $include = $self->{dom_doc}->createElement($self->{xsd} . ":include");
		$include->setAttribute("href", "http://www.omg.org/IDL-WSDL/1.0/");
		$grammar->appendChild($include);
	}

	$self->_any($grammar);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $grammar);
	}

	$grammar->appendChild($self->{dom_start}) if (exists $self->{dom_start});

	print $FH "<!-- This file was generated (by ",$0,"). DO NOT modify it -->\n";
	print $FH "<!-- From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH "     Generation date : ",POSIX::ctime(time());
	print $FH "-->\n";
	print $FH "\n";
	print $FH $self->_beautify($self->{dom_doc}->toString());
	print $FH "\n\n";
	print $FH "<!-- end of file : ",$self->{filename}," -->\n";
	close $FH;
	$self->{dom_doc}->dispose();
}

sub _any {
	my $self = shift;
	my ($dom_parent) = @_;

	return unless ($self->{root}->{need_any});

	#	See	1.2.7.7		TypeCode
	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", "CORBA.TypeCode");
	$dom_parent->appendChild($define);

	my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "definition");
	$group->appendChild($element);

	my $data = $self->{dom_doc}->createElement($self->{rng} . ":data");
	$data->setAttribute("type", $self->{xsd} . ":url");
	$element->appendChild($data);

	$element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "typename");
	$group->appendChild($element);

	$data = $self->{dom_doc}->createElement($self->{rng} . ":data");
	$data->setAttribute("type", $self->{xsd} . ":string");
	$element->appendChild($data);

	#	See	1.2.7.8		Any
	$define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", "CORBA.Any");
	$dom_parent->appendChild($define);

	$group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	$element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "type");
	$group->appendChild($element);

	my $ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
	$ref->setAttribute("name", "CORBA.TypeCode");
	$element->appendChild($ref);

	$element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "value");
	$group->appendChild($element);

	$data = $self->{dom_doc}->createElement($self->{rng} . ":data");
	$data->setAttribute("type", $self->{xsd} . ":anyType");
	$element->appendChild($data);

	delete $self->{root}->{need_any};
}

#
#	3.7		Module Declaration
#

sub visitModules {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	unless (exists $node->{$self->{num_key}}) {
		$node->{$self->{num_key}} = 0;
	}
	my $module = ${$node->{list_decl}}[$node->{$self->{num_key}}];
	$module->visit($self, $dom_parent);
	$node->{$self->{num_key}} ++;
}

sub visitModule {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

#
#	3.8		Interface Declaration
#
#	See 1.2.8		Interfaces
#

sub visitInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

sub visitLocalInterface {
	shift->_no_mapping(@_);
}

sub visitForwardBaseInterface {
#	empty
}

#
#	3.9		Value Declaration
#
#	See	1.2.7.10	ValueType
#

sub visitRegularValue {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	foreach (@{$node->{list_decl}}) {
		my $value_element = $self->_get_defn($_);
		if (	   $value_element->isa('StateMembers')
				or $value_element->isa('Initializer')
				or $value_element->isa('Operation')
				or $value_element->isa('Attributes') ) {
			next;
		}
		$value_element->visit($self, $dom_parent);
	}

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	foreach (values %{$node->{hash_attribute_operation}}) {
		my $defn = $self->_get_defn($_);
		if ($defn->isa('StateMember')) {
			$defn->visit($self, $group);
		}
	}

	$self->_value_id($define);

	$self->_standalone($node, $dom_parent);
}

sub _value_id {
	my $self = shift;
	my ($dom_parent) = @_;

	my $optional = $self->{dom_doc}->createElement($self->{rng} . ":optional");
	$dom_parent->appendChild($optional);

	my $attribute = $self->{dom_doc}->createElement($self->{rng} . ":attribute");
	$attribute->setAttribute("name", "id");
	$optional->appendChild($attribute);

	my $data = $self->{dom_doc}->createElement($self->{rng} . ":data");
	$data->setAttribute("type", "ID");
	$attribute->appendChild($data);
}

sub visitStateMember {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});
	if (exists $node->{array_size}) {
		# like Array
		my $idx = scalar(@{$node->{array_size}}) - 1;
		my $current = $type;
		while ($current->isa('SequenceType')) {
			$idx ++;
			$current = $self->_get_defn($current->{type});
		}

		my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($element);

		$current = $element;
		my $first = 1;
		foreach (reverse @{$node->{array_size}}) {
			my $oneOrMore = $self->{dom_doc}->createElement($self->{rng} . ":oneOrMore");
			$current->appendChild($oneOrMore);

			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			my $item = ($idx != 0) ? "item" . $idx : "item";
			$element->setAttribute("name", $item);
			$oneOrMore->appendChild($element);

			$current = $element;
			$idx --;
			$first = 0;
		}

		if ($type->isa('SequenceType')) {
			$type->visit($self, $current);
		} else {
			$self->_ref_type($type, $current);
		}
	} else {
		if ($type->isa('RegularValue')) {
			my $choice = $self->{dom_doc}->createElement($self->{rng} . ":choice");
			$dom_parent->appendChild($choice);

			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			$element->setAttribute("name", $node->{xsd_name});
			$choice->appendChild($element);

			my $ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
			$ref->setAttribute("name", $type->{xsd_name});
			$element->appendChild($ref);

			$element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			$element->setAttribute("name", "_REF_" . $node->{xsd_name});
			$choice->appendChild($element);

			$ref = $self->{dom_doc}->createElement($self->{rng} . ":ref");
			$ref->setAttribute("name", "_VALREF");
			$element->appendChild($ref);
		} else {
			# like Single
			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			$element->setAttribute("name", $node->{xsd_name});
			$dom_parent->appendChild($element);

			if ($type->isa('SequenceType')) {
				$type->visit($self, $element);
			} else {
				$self->_ref_type($type, $element);
			}
		}
	}
}

sub visitBoxedValue {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});
	if (	   $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType') ) {
		$type->visit($self, $dom_parent);
	}

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "value");
	$group->appendChild($element);

	if ($type->isa('SequenceType')) {
		$type->visit($self, $element);
	} else {
		$self->_ref_type($type, $element);
	}

	$self->_value_id($define);

	$self->_standalone($node, $dom_parent);
}

sub visitAbstractValue {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	foreach (@{$node->{list_decl}}) {
		my $value_element = $self->_get_defn($_);
		if (	   $value_element->isa('Operation')
				or $value_element->isa('Attributes') ) {
			next;
		}
		$value_element->visit($self, $dom_parent);
	}
}

#
#	3.10	Constant Declaration
#
#	See	1.2.6.1		Constants
#

sub visitConstant {
#	empty
}

#
#	3.11	Type Declaration
#
#	See	1.2.7.3		Typedefs
#

sub visitTypeDeclarators {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

sub visitTypeDeclarator {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	return if (exists $node->{modifier});	# native IDL2.2

	my $type = $self->_get_defn($node->{type});
	if (	   $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType') ) {
		$type->visit($self, $dom_parent);
	}

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	if (exists $node->{array_size}) {
		#
		#	See	1.2.7.6	Arrays
		#
		warn __PACKAGE__,"::visitTypeDecalarator $node->{idf} : empty array_size.\n"
				unless (@{$node->{array_size}});

		my $idx = scalar(@{$node->{array_size}}) - 1;
		my $current = $type;
		while ($current->isa('SequenceType')) {
			$idx ++;
			$current = $self->_get_defn($current->{type});
		}

		$current = $define;
		my $first = 1;
		foreach (reverse @{$node->{array_size}}) {
			my $oneOrMore = $self->{dom_doc}->createElement($self->{rng} . ":oneOrMore");
			$current->appendChild($oneOrMore);

			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			my $item = ($idx != 0) ? "item" . $idx : "item";
			$element->setAttribute("name", $item);
			$oneOrMore->appendChild($element);

			$current = $element;
			$idx --;
			$first = 0;
		}

		if ($type->isa('SequenceType')) {
			$type->visit($self, $current);
		} else {
			$self->_ref_type($type, $current);
		}
	} else {
		if ($type->isa('SequenceType')) {
			$type->visit($self, $define);
		} else {
			$self->_ref_type($type, $define);
		}
	}

	$self->_standalone($node, $dom_parent);
}

#
#	3.11.1	Basic Types
#

sub visitCharType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $param = $self->{dom_doc}->createElement($self->{rng} . ":param");
	$param->setAttribute("name", "length");
	$dom_parent->appendChild($param);

	my $value = $self->{dom_doc}->createTextNode("1");
	$param->appendChild($value);
}

sub visitBasicType {
# empty
}

#
#	3.11.2	Constructed Types
#
#	3.11.2.1	Structures
#
#	See	1.2.7.2		Structure
#

sub visitStructType {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType') ) {
			$type->visit($self, $dom_parent);
		}
	}

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	foreach (@{$node->{list_member}}) {
		$self->_get_defn($_)->visit($self, $group);
	}

	$self->_standalone($node, $dom_parent);
}

sub visitMember {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($element);

	my $current = $element;
	if (exists $node->{array_size}) {
		my $idx = scalar(@{$node->{array_size}}) - 1;
		my $curr = $type;
		while ($curr->isa('SequenceType')) {
			$idx ++;
			$curr = $self->_get_defn($curr->{type});
		}
		my $first = 1;
		foreach (reverse @{$node->{array_size}}) {
			my $oneOrMore = $self->{dom_doc}->createElement($self->{rng} . ":oneOrMore");
			$current->appendChild($oneOrMore);

			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			my $item = ($idx != 0) ? "item" . $idx : "item";
			$element->setAttribute("name", $item);
			$oneOrMore->appendChild($element);

			$current = $element;
			$idx --;
			$first = 0;
		}
	}

	if ($type->isa('SequenceType')) {
		$type->visit($self, $current);
	} else {
		$self->_ref_type($type, $current);
	}
}

#	3.11.2.2	Discriminated Unions
#
#	See	1.2.7.4		Unions
#

sub visitUnionType {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{element}->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType') ) {
			$type->visit($self, $dom_parent);
		}
	}

	my $type = $self->_get_defn($node->{type});

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
	$define->appendChild($group);

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", "discriminator");
	$group->appendChild($element);

	if ($type->isa('EnumType')) {
		$type->visit($self, $element, 1);
	} else {
		my $data = $self->{dom_doc}->createElement($self->{rng} . ":data");
		$data->setAttribute("type", $type->{xsd_name});
		$element->appendChild($data);
	}

	my $choice = $self->{dom_doc}->createElement($self->{rng} . ":choice");
	$group->appendChild($choice);

	foreach (@{$node->{list_expr}}) {
		$_->visit($self, $choice);				# case
	}

	$self->_standalone($node, $dom_parent);
}

sub visitCase {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $str = " case";
	my $first = 1;
	foreach (@{$node->{list_label}}) {
		$str .= "," unless ($first);
		$str .= " ";
		if ($_->isa('Default')) {
			$str .= "default";
		} else {
			$str .= $self->_value($_);
		}
		$first = 0;
	}
	$str .= " ";

	my $comment = $self->{dom_doc}->createComment($str);
	$dom_parent->appendChild($comment);

	$self->_get_defn($node->{element}->{value})->visit($self, $dom_parent);		# single or array
}

#	3.11.2.3	Constructed Recursive Types and Forward Declarations
#

sub visitForwardStructType {
	# empty
}

sub visitForwardUnionType {
	# empty
}

#	3.11.2.4	Enumerations
#
#	See	1.2.7.1		Enum
#

sub visitEnumType {
	my $self = shift;
	my ($node, $dom_parent, $indirect) = @_;
	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	my $choice = $self->{dom_doc}->createElement($self->{rng} . ":choice");

	if ($indirect) {
		$dom_parent->appendChild($choice);
	} else {
		my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
		$define->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($define);

		$define->appendChild($choice);
	}

	foreach (@{$node->{list_expr}}) {
		$_->visit($self, $choice);				# enum
	}

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

sub visitEnum {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	my $FH = $self->{out};

	my $value = $self->{dom_doc}->createElement($self->{rng} . ":value");
	$dom_parent->appendChild($value);

	my $text = $self->{dom_doc}->createTextNode($node->{xsd_name});
	$value->appendChild($text);
}

#
#	3.11.3	Template Types
#
#	See	1.2.7.5		Sequences
#

sub visitSequenceType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});
	my $idx = 0;
	my $current = $type;
	while ($current->isa('SequenceType')) {
		$idx ++;
		$current = $self->_get_defn($current->{type});
	}

	my $zeroOrMore = $self->{dom_doc}->createElement($self->{rng} . ":zeroOrMore");
	$dom_parent->appendChild($zeroOrMore);

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	my $item = ($idx != 0) ? "item" . $idx : "item";
	$element->setAttribute("name", $item);
	$zeroOrMore->appendChild($element);

	if ($type->isa('SequenceType')) {
		$type->visit($self, $element);
	} else {
		$self->_ref_type($type, $element);
	}
}

#
#	See	1.2.6	Primitive Types
#

sub visitStringType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	if (exists $node->{max}) {
		my $param = $self->{dom_doc}->createElement($self->{rng} . ":param");
		$param->setAttribute("name", "maxLength");
		$dom_parent->appendChild($param);

		my $value = $self->{dom_doc}->createTextNode($self->_value($node->{max}));
		$param->appendChild($value);
	}
}

#
#	See	1.2.6	Primitive Types
#

sub visitWideStringType {
# empty
}

#
#	See	1.2.7.9		Fixed
#

sub visitFixedPtType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $param = $self->{dom_doc}->createElement($self->{rng} . ":param");
	$param->setAttribute("name", "totalDigits");
	$dom_parent->appendChild($param);

	my $value = $self->{dom_doc}->createTextNode($self->_value($node->{d}));
	$param->appendChild($value);

	$param = $self->{dom_doc}->createElement($self->{rng} . ":param");
	$param->setAttribute("name", "fractionDigits");
	$dom_parent->appendChild($param);

	$value = $self->{dom_doc}->createTextNode($self->_value($node->{s}));
	$param->appendChild($value);
}

#
#	3.12	Exception Declaration
#
#	See	1.2.8.5		Exceptions
#

sub visitException {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	if (exists $node->{list_expr}) {
		warn __PACKAGE__,"::visitException $node->{idf} : empty list_expr.\n"
				unless (@{$node->{list_expr}});
		foreach (@{$node->{list_expr}}) {
			my $type = $self->_get_defn($_->{type});
			if (	   $type->isa('StructType')
					or $type->isa('UnionType') ) {
				$type->visit($self, $dom_parent);
			}
		}
	}

	my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
	$define->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($define);

	if (scalar @{$node->{list_member}}) {
		my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
		$define->appendChild($group);

		foreach (@{$node->{list_member}}) {
			$self->_get_defn($_)->visit($self, $group);
		}
	} else {
		my $empty = $self->{dom_doc}->createElement($self->{rng} . ":empty");
		$define->appendChild($empty);
	}

	$self->_standalone($node, $dom_parent);
}

#
#	3.13	Operation Declaration
#
#	See	1.2.8.2		Interface as Binding Operations
#

sub visitOperation {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	return unless ($self->{standalone});

	if (scalar(@{$node->{list_in}}) + scalar(@{$node->{list_inout}})) {
		my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
		$define->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($define);

		my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
		$define->appendChild($group);

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'in'
					or $_->{attr} eq 'inout' ) {
				$_->visit($self, $group);
			}
		}
	}

	my $type = $self->_get_defn($node->{type});
	if (scalar(@{$node->{list_inout}}) + scalar(@{$node->{list_out}})
			or ! $type->isa('VoidType') ) {
		my $define = $self->{dom_doc}->createElement($self->{rng} . ":define");
		$define->setAttribute("name", $node->{xsd_name} . "Response");
		$dom_parent->appendChild($define);

		my $group = $self->{dom_doc}->createElement($self->{rng} . ":group");
		$define->appendChild($group);

		unless ($type->isa("VoidType")) {
			my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
			$element->setAttribute("name", $node->{xsd_name});
			$group->appendChild($element);

			$self->_ref_type($type, $element);
		}

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'inout'
					or $_->{attr} eq 'out' ) {
				$_->visit($self, $group);
			}
		}
	}
}

sub visitParameter {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});

	my $element = $self->{dom_doc}->createElement($self->{rng} . ":element");
	$element->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($element);

	$self->_ref_type($type, $element);
}

#
#	3.14	Attribute Declaration
#

sub visitAttributes {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

sub visitAttribute {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	$node->{_get}->visit($self, $dom_parent);
	$node->{_set}->visit($self, $dom_parent)
			if (exists $node->{_set});
}

#
#	3.15	Repository Identity Related Declarations
#

sub visitTypeId {
	# empty
}

sub visitTypePrefix {
	# empty
}

#
#	3.16	Event Declaration
#

sub visitEvent {
	shift->_no_mapping(@_);
}

#
#	3.17	Component Declaration
#

sub visitComponent {
	shift->_no_mapping(@_);
}

#
#	3.18	Home Declaration
#

sub visitHome {
	shift->_no_mapping(@_);
}

1;

