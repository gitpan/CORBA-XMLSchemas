use strict;

use POSIX qw(ctime);
use XML::DOM;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#
#			CORBA to WSDL/SOAP Interworking Specification, Version 1.0 November 2003
#

package XsdVisitor;

# needs $node->{xsd_name} $node->{xsd_qname} (XsdNameVisitor)

use vars qw($VERSION);
$VERSION = '0.02';

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser, $standalone) = @_;
	$self->{standalone} = $standalone;
	$self->{tns} = 'tns';
	$self->{xsd} = 'xs';
	$self->{corba} = 'corba';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{root} = $parser->YYData->{root};
	my $filename = $self->{srcname};
	$filename =~ s/^([^\/]+\/)+//;
	$filename =~ s/\.idl$//i;
	$filename .= '.xsd';
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_inc_xsd';
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
	if ($value->isa('Enum')) {
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
		$out .= join('', @tab) . "$_\n";
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

sub _standalone {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	if ($self->{standalone}) {
		my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$element->setAttribute("type", $node->{xsd_qname});
		$dom_parent->appendChild($element);
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

	my $schema = $self->{dom_doc}->createElement($self->{xsd} . ":schema");
	$schema->setAttribute("targetNamespace", "http://www.omg.org/IDL-Mapped");
	$schema->setAttribute("xmlns:" . $self->{xsd}, "http://www.w3.org/2001/XMLSchema");
	$schema->setAttribute("xmlns:" . $self->{corba}, "http://www.omg.org/IDL-WSDL/1.0")
			if ($self->{root}->{need_corba});
	$schema->setAttribute("xmlns:" . $self->{tns}, "http://www.omg.org/IDL-Mapped");
	$schema->setAttribute("elementFormDefault", "qualified");
	$schema->setAttribute("attributeFormDefault", "unqualified");
	$self->{dom_parent}->appendChild($schema);

	if ($self->{root}->{need_corba}) {
		my $import = $self->{dom_doc}->createElement($self->{xsd} . ":import");
		$import->setAttribute("namespace", "http://www.omg.org/IDL-WSDL/1.0");
		$import->setAttribute("schemaLocation", "http://www.omg.org/IDL-WSDL/1.0");
		$schema->appendChild($import);
	}

	$self->_any($schema);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $schema);
	}

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
	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", "CORBA.TypeCode");
	$dom_parent->appendChild($complexType);

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$complexType->appendChild($sequence);

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "definition");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{xsd} . ":url");
	$sequence->appendChild($element);

	$element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "typename");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{xsd} . ":string");
	$sequence->appendChild($element);

	#	See	1.2.7.8		Any
	$complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", "CORBA.Any");
	$dom_parent->appendChild($complexType);

	$sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$complexType->appendChild($sequence);

	$element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "type");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{tns} . ":CORBA.TypeCode");
	$sequence->appendChild($element);

	$element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "value");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{xsd} . ":anyType");
	$sequence->appendChild($element);

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

sub visitRegularInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

sub visitAbstractInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

sub visitLocalInterface {
	shift->_no_mapping(@_);
}

sub visitForwardRegularInterface {
#	empty
}

sub visitForwardAbstractInterface {
#	empty
}

sub visitForwardLocalInterface {
#	empty
}

#
#	3.9		Value Declaration
#
#	See	1.2.7.10	ValueType
#

sub visitRegularValue {
	my $self = shift;
	my ($node, $dom_parent, $indirect) = @_;

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

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($complexType);

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$complexType->appendChild($sequence);

	foreach (values %{$node->{hash_attribute_operation}}) {
		my $defn = $self->_get_defn($_);
		if ($defn->isa('StateMember')) {
			$defn->visit($self, $sequence);
		}
	}

	$self->_value_id($complexType);

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

sub _value_id {
	my $self = shift;
	my ($dom_parent) = @_;

	my $attribute = $self->{dom_doc}->createElement($self->{xsd} . ":attribute");
	$attribute->setAttribute("name", "id");
	$attribute->setAttribute("type", $self->{xsd} . ":ID");
	$attribute->setAttribute("use", "optional");
	$dom_parent->appendChild($attribute);

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

		my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$element->setAttribute("maxOccurs", "1");
		$element->setAttribute("minOccurs", "1");
		$dom_parent->appendChild($element);

		$current = $element;
		my $first = 1;
		foreach (reverse @{$node->{array_size}}) {
			my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
			$current->appendChild($complexType);

			my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
			$complexType->appendChild($sequence);

			my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			my $item = ($idx != 0) ? "item" . $idx : "item";
			$element->setAttribute("name", $item);
			$element->setAttribute("minOccurs", $self->_value($_));
			$element->setAttribute("maxOccurs", $self->_value($_));
			$sequence->appendChild($element);

			$current = $element;
			$idx --;
			$first = 0;
		}
		if ($type->isa('SequenceType')) {
			my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
			$current->appendChild($complexType);

			$type->visit($self, $complexType);
		} else {
			$current->setAttribute("type", $type->{xsd_qname});
		}
	} else {
		if ($type->isa('RegularValue')) {
			my $choice = $self->{dom_doc}->createElement($self->{xsd} . ":choice");
			$dom_parent->appendChild($choice);

			my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			$element->setAttribute("name", $node->{xsd_name});
			$element->setAttribute("maxOccurs", "1");
			$element->setAttribute("minOccurs", "1");
			$element->setAttribute("type", $type->{xsd_qname});
			$choice->appendChild($element);

			$element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			$element->setAttribute("name", "_REF_" . $node->{xsd_name});
			$element->setAttribute("maxOccurs", "1");
			$element->setAttribute("minOccurs", "1");
			$element->setAttribute("type", $self->{corba} . ":_VALREF");
			$choice->appendChild($element);
		} else {
			# like Single
			my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			$element->setAttribute("name", $node->{xsd_name});
			$element->setAttribute("maxOccurs", "1");
			$element->setAttribute("minOccurs", "1");
			$element->setAttribute("nillable", "true")
					if ($type->isa('StringType') or $type->isa('WideStringType'));
			$dom_parent->appendChild($element);

			if ($type->isa('SequenceType')) {
				my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
				$element->appendChild($complexType);

				$type->visit($self, $complexType);
			} else {
				$element->setAttribute("type", $type->{xsd_qname});
			}
		}
	}
}

sub visitBoxedValue {
	my $self = shift;
	my ($node, $dom_parent, $indirect) = @_;

	my $type = $self->_get_defn($node->{type});
	if (	   $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType') ) {
		$type->visit($self, $dom_parent);
	}

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($complexType);

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$complexType->appendChild($sequence);

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "value");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("nillable", "true")
			if ($type->isa('StringType') or $type->isa('WideStringType'));
	$sequence->appendChild($element);

	if ($type->isa('SequenceType')) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$element->appendChild($complexType);

		$type->visit($self, $complexType);
	} else {
		$element->setAttribute("type", $type->{xsd_qname});
	}

	$self->_value_id($complexType);

	$self->_standalone($node, $dom_parent) unless ($indirect);
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

sub visitForwardRegularValue {
#	empty
}

sub visitForwardAbstractValue {
#	empty
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
	my ($node, $dom_parent, $indirect) = @_;
	return if (exists $node->{modifier});	# native IDL2.2

	my $type = $self->_get_defn($node->{type});
	while ($type->isa('TypeDeclarator') and !exists $type->{array_size}) {
		$type = $self->_get_defn($type->{type});
	}

	if (	   $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType') ) {
		$type->visit($self, $dom_parent);
	}

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

		$current = $dom_parent;
		my $first = 1;
		foreach (reverse @{$node->{array_size}}) {
			my $complexType;
			if ($indirect and $first) {
				$complexType = $dom_parent;
			} else {
				$complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
				$complexType->setAttribute("name", $node->{xsd_name})
						if ($first);
				$current->appendChild($complexType);
			}

			my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
			$complexType->appendChild($sequence);

			my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			my $item = ($idx != 0) ? "item" . $idx : "item";
			$element->setAttribute("name", $item);
			$element->setAttribute("minOccurs", $self->_value($_));
			$element->setAttribute("maxOccurs", $self->_value($_));
			$sequence->appendChild($element);

			$current = $element;
			$idx --;
			$first = 0;
		}
		if ($type->isa('SequenceType')) {
			my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
			$current->appendChild($complexType);

			$type->visit($self, $complexType);
		} else {
			$current->setAttribute("type", $type->{xsd_qname});
		}
	} else {
		if (	   $type->isa('SequenceType')
				or $type->isa('TypeDeclarator') ) {
			my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
			$complexType->setAttribute("name", $node->{xsd_name});
			$dom_parent->appendChild($complexType);

			$type->visit($self, $complexType, 1);
		} else {
			if (	   $type->isa('Value')
					or $type->isa('StructType')
					or $type->isa('UnionType') ) {
				my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
				$complexType->setAttribute("name", $node->{xsd_name});
				$dom_parent->appendChild($complexType);

				my $complexContext = $self->{dom_doc}->createElement($self->{xsd} . ":complexContent");
				$complexType->appendChild($complexContext);

				my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
				$restriction->setAttribute("base", $type->{xsd_qname});
				$complexContext->appendChild($restriction);

				$type->visit($self, $restriction, 1);
			} else {
				my $simpleType = $self->{dom_doc}->createElement($self->{xsd} . ":simpleType");
				$simpleType->setAttribute("name", $node->{xsd_name});
				$dom_parent->appendChild($simpleType);

				if (	   $type->isa('EnumType')
						or $type->isa('BaseInterface') ) {
					my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
					$restriction->setAttribute("base", $type->{xsd_qname});
					$simpleType->appendChild($restriction);
				} else {
					$type->visit($self, $simpleType);
				}
			}
		}
	}

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

#
#	3.11.1	Basic Types
#

sub visitCharType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $node->{xsd_qname});
	$dom_parent->appendChild($restriction);

	my $length = $self->{dom_doc}->createElement($self->{xsd} . ":length");
	$length->setAttribute("value", "1");
	$length->setAttribute("fixed", "true");
	$restriction->appendChild($length);
}

sub visitBasicType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $node->{xsd_qname});
	$dom_parent->appendChild($restriction);
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
	my ($node, $dom_parent, $indirect) = @_;

	if ($indirect) {
		$self->_StructType_Content($node, $dom_parent);
		return;
	}

	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType') ) {
			$type->visit($self, $dom_parent);
		}
	}

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($complexType);

	$self->_StructType_Content($node, $complexType);

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

sub _StructType_Content {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$dom_parent->appendChild($sequence);

	foreach (@{$node->{list_value}}) {
		$self->_get_defn($_)->visit($self, $sequence);		# single or array
	}
}

sub visitArray {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});
	my $idx = scalar(@{$node->{array_size}}) - 1;
	my $current = $type;
	while ($current->isa('SequenceType')) {
		$idx ++;
		$current = $self->_get_defn($current->{type});
	}

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", $node->{xsd_name});
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$dom_parent->appendChild($element);

	$current = $element;
	my $first = 1;
	foreach (reverse @{$node->{array_size}}) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$current->appendChild($complexType);

		my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
		$complexType->appendChild($sequence);

		my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
		my $item = ($idx != 0) ? "item" . $idx : "item";
		$element->setAttribute("name", $item);
		$element->setAttribute("minOccurs", $self->_value($_));
		$element->setAttribute("maxOccurs", $self->_value($_));
		$sequence->appendChild($element);

		$current = $element;
		$idx --;
		$first = 0;
	}
	if ($type->isa('SequenceType')) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$current->appendChild($complexType);

		$type->visit($self, $complexType);
	} else {
		$current->setAttribute("type", $type->{xsd_qname});
	}
}

sub visitSingle {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", $node->{xsd_name});
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("nillable", "true")
			if ($type->isa('StringType') or $type->isa('WideStringType'));
	$dom_parent->appendChild($element);

	if ($type->isa('SequenceType')) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$element->appendChild($complexType);

		$type->visit($self, $complexType);
	} else {
		$element->setAttribute("type", $type->{xsd_qname});
	}
}

#	3.11.2.2	Discriminated Unions
#
#	See	1.2.7.4		Unions
#

sub visitUnionType {
	my $self = shift;
	my ($node, $dom_parent, $indirect) = @_;

	if ($indirect) {
		$self->_UnionType_Content($node, $dom_parent);
		return;
	}

	return if (exists $self->{done_hash}->{$node->{xsd_name}});
	$self->{done_hash}->{$node->{xsd_name}} = 1;

	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{element}->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType') ) {
			$type->visit($self, $dom_parent);
		}
	}

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($complexType);

	$self->_UnionType_Content($node, $complexType);

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

sub _UnionType_Content {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $type = $self->_get_defn($node->{type});

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$dom_parent->appendChild($sequence);

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "discriminator");
	$sequence->appendChild($element);

	if ($type->isa('EnumType')) {
		$type->visit($self, $element, 1);
	} else {
		$element->setAttribute("type", $type->{xsd_qname});
	}

	my $choice = $self->{dom_doc}->createElement($self->{xsd} . ":choice");
	$sequence->appendChild($choice);

	foreach (@{$node->{list_expr}}) {
		$_->visit($self, $choice);				# case
	}
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

	my $simpleType = $self->{dom_doc}->createElement($self->{xsd} . ":simpleType");
	$simpleType->setAttribute("name", $node->{xsd_name})
			unless ($indirect);
	$dom_parent->appendChild($simpleType);

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $self->{xsd} . ":string");
	$simpleType->appendChild($restriction);

	foreach (@{$node->{list_expr}}) {
		$_->visit($self, $restriction);				# enum
	}

	$self->_standalone($node, $dom_parent) unless ($indirect);
}

sub visitEnum {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	my $FH = $self->{out};

	my $enumeration = $self->{dom_doc}->createElement($self->{xsd} . ":enumeration");
	$enumeration->setAttribute("value", $node->{xsd_name});
	$dom_parent->appendChild($enumeration);
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

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$dom_parent->appendChild($sequence);

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	my $item = ($idx != 0) ? "item" . $idx : "item";
	$element->setAttribute("name", $item);
	$element->setAttribute("minOccurs", 0);
	my $max = (exists $node->{max}) ? $self->_value($node->{max}) : "unbounded";
	$element->setAttribute("maxOccurs", $max);
	$sequence->appendChild($element);

	if ($type->isa('SequenceType')) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$element->appendChild($complexType);

		$type->visit($self, $complexType);
	} else {
		$element->setAttribute("type", $type->{xsd_qname});
	}
}

#
#	See	1.2.6	Primitive Types
#

sub visitStringType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $node->{xsd_qname});
	$dom_parent->appendChild($restriction);

	if (exists $node->{max}) {
		my $maxLength = $self->{dom_doc}->createElement($self->{xsd} . ":maxLength");
		$maxLength->setAttribute("value", $self->_value($node->{max}));
		$maxLength->setAttribute("fixed", "true");
		$restriction->appendChild($maxLength);
	}
}

#
#	See	1.2.6	Primitive Types
#

sub visitWideStringType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $node->{xsd_qname});
	$dom_parent->appendChild($restriction);
}

#
#	See	1.2.7.9		Fixed
#

sub visitFixedPtType {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $node->{xsd_qname});
	$dom_parent->appendChild($restriction);

	my $totalDigits = $self->{dom_doc}->createElement($self->{xsd} . ":totalDigits");
	$totalDigits->setAttribute("value", $self->_value($node->{d}));
	$restriction->appendChild($totalDigits);

	my $fractionDigits = $self->{dom_doc}->createElement($self->{xsd} . ":fractionDigits");
	$fractionDigits->setAttribute("value", $self->_value($node->{s}));
	$fractionDigits->setAttribute("fixed", "true");
	$restriction->appendChild($fractionDigits);
}

#
#	3.12	Exception Declaration
#
#	See	1.2.8.5		Exceptions
#

sub visitException {
	my $self = shift;
	my ($node, $dom_parent, $indirect) = @_;

	if ($indirect) {
		$self->_StructType_Content($node, $dom_parent);
		return;
	}

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

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", $node->{xsd_name});
	$dom_parent->appendChild($complexType);

	$self->_StructType_Content($node, $complexType);

	$self->_standalone($node, $dom_parent) unless ($indirect);
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
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$complexType->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($complexType);

		my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
		$complexType->appendChild($sequence);

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'in'
					or $_->{attr} eq 'inout' ) {
				$_->visit($self, $sequence);
			}
		}

		my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
		$element->setAttribute("name", $node->{xsd_name});
		$element->setAttribute("type", $node->{xsd_qname});
		$dom_parent->appendChild($element);
	}

	my $type = $self->_get_defn($node->{type});
	if (scalar(@{$node->{list_inout}}) + scalar(@{$node->{list_out}})
			or ! $type->isa('VoidType') ) {
		my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
		$complexType->setAttribute("name", $node->{xsd_name} . "Response");
		$dom_parent->appendChild($complexType);

		my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
		$complexType->appendChild($sequence);

		unless ($type->isa("VoidType")) {
			my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
			$element->setAttribute("name", "_return");
			$element->setAttribute("maxOccurs", "1");
			$element->setAttribute("minOccurs", "1");
			$element->setAttribute("nillable", "true")
					if ($type->isa('StringType') or $type->isa('WideStringType'));
			$element->setAttribute("type", $type->{xsd_qname});
			$sequence->appendChild($element);
		}

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'inout'
					or $_->{attr} eq 'out' ) {
				$_->visit($self, $sequence);
			}
		}

		my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
		$element->setAttribute("name", $node->{xsd_name} . "Response");
		$element->setAttribute("type", $node->{xsd_qname} . "Response");
		$dom_parent->appendChild($element);
	}
}

sub visitParameter {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	my $type = $self->_get_defn($node->{type});

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", $node->{xsd_name});
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("nillable", "true")
			if ($type->isa('StringType') or $type->isa('WideStringType'));
	$element->setAttribute("type", $type->{xsd_qname});
	$dom_parent->appendChild($element);
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

sub visitRegularEvent {
	shift->_no_mapping(@_);
}

sub visitAbstractEvent {
	shift->_no_mapping(@_);
}

sub visitForwardRegularEvent {
	shift->_no_mapping(@_);
}

sub visitForwardAbstractEvent {
	shift->_no_mapping(@_);
}

#
#	3.17	Component Declaration
#

sub visitComponent {
	shift->_no_mapping(@_);
}

sub visitForwardComponent {
	shift->_no_mapping(@_);
}

#
#	3.18	Home Declaration
#

sub visitHome {
	shift->_no_mapping(@_);
}

1;

