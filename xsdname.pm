use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#
#			CORBA to WSDL/SOAP Interworking Specification, Version 1.0 November 2003
#

package XsdNameVisitor;

# builds $node->{xsd_name} and $node->{xsd_qname}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser, $ns) = @_;
	$self->{key} = 'xsd_name';
	$self->{tns} = 'tns';
	$self->{xsd} = $ns || 'xs';
	$self->{corba} = 'corba';
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{root} = $parser->YYData->{root};
	return $self;
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

#
#	See	1.2		Scoped Names
#
sub _get_name {
	my $self = shift;
	my ($node) = @_;
	my $name = $node->{full};
	$name =~ s/^:://;
	$name =~ s/::/\./g;
	return $name;
}

#
#	3.5		OMG IDL Specification
#

sub visitNameSpecification {
	my $self = shift;
	my ($node) = @_;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.7		Module Declaration
#

sub visitNameModules {
	my $self = shift;
	my ($node) = @_;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.8		Interface Declaration
#

sub visitNameBaseInterface {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{xsd_name});
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . "CORBA.ObjectReference";
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.9		Value Declaration
#

sub visitNameRegularValue {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{xsd_name});
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

sub visitNameStateMember {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $node->{idf};
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

sub visitNameInitializer {
	# empty
}

sub visitNameBoxedValue {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{xsd_name});
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

#
#	3.10	Constant Declaration
#

sub visitNameConstant {
	# empty
}

#
#	3.11	Type Declaration
#

sub visitNameTypeDeclarator {
	my $self = shift;
	my ($node) = @_;
	if (exists $node->{modifier}) {		# native IDL2.2
		$node->{xsd_name} = $node->{idf};
	} else {
		$node->{xsd_name} = $self->_get_name($node);
		$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
		my $type = $self->_get_defn($node->{type});
		$type->visitName($self);
		$self->{root}->{need_corba} = 1
				if ($type->isa('BaseInterface'));
	}
}

#
#	3.11.1	Basic Types
#
#	See	1.2.6		Primitive Types
#

sub visitNameBasicType {
	my $self = shift;
	my ($node) = @_;
	if      ($node->isa('FloatingPtType')) {
		if      ($node->{value} eq 'float') {
			$node->{xsd_name} = "float";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'double') {
			$node->{xsd_name} = "double";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'long double') {
			$node->{xsd_name} = "double";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} else {
			warn __PACKAGE__,"::visitNameBasicType (FloatingType) $node->{value}.\n";
		}
	} elsif ($node->isa('IntegerType')) {
		if      ($node->{value} eq 'short') {
			$node->{xsd_name} = "short";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'unsigned short') {
			$node->{xsd_name} = "unsignedShort";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'long') {
			$node->{xsd_name} = "int";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'unsigned long') {
			$node->{xsd_name} = "unsignedInt";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'long long') {
			$node->{xsd_name} = "long";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} elsif ($node->{value} eq 'unsigned long long') {
			$node->{xsd_name} = "unsignedLong";
			$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
		} else {
			warn __PACKAGE__,"::visitNameBasicType (IntegerType) $node->{value}.\n";
		}
	} elsif ($node->isa('CharType')) {
		$node->{xsd_name} = "string";
		$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
	} elsif ($node->isa('WideCharType')) {
		$node->{xsd_name} = "string";
		$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
	} elsif ($node->isa('BooleanType')) {
		$node->{xsd_name} = "boolean";
		$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
	} elsif ($node->isa('OctetType')) {
		$node->{xsd_name} = "unsignedByte";
		$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
	} elsif ($node->isa('AnyType')) {		# See 1.2.7.8	Any
		$node->{xsd_name} = "CORBA.Any";
		$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
		$self->{root}->{need_any} = 1;
	} elsif ($node->isa('ObjectType')) {	# See 1.2.5		Object References
		$node->{xsd_name} = "ObjectReference";
		$node->{xsd_qname} = $self->{corba} . ":" . $node->{xsd_name};
		$self->{root}->{need_corba} = 1;
	} elsif ($node->isa('ValueBaseType')) {
		$node->{xsd_name} = "ObjectReference";
		$node->{xsd_qname} = $self->{corba} . ":" . $node->{xsd_name};
		$self->{root}->{need_corba} = 1;
	} else {
		warn __PACKAGE__,"::visitNameBasicType INTERNAL ERROR (",ref $node,").\n";
	}
}

#
#	3.11.2	Constructed Types
#
#	3.11.2.1	Structures
#

sub visitNameStructType {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{xsd_name});
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	foreach (@{$node->{list_value}}) {
		$self->_get_defn($_)->visitName($self);		# single or array
	}
}

sub visitNameArray {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $node->{idf};
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

sub visitNameSingle {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $node->{idf};
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

#	3.11.2.2	Discriminated Unions
#

sub visitNameUnionType {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{xsd_name});
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	$self->_get_defn($node->{type})->visitName($self);
	foreach (@{$node->{list_expr}}) {
		$_->{element}->visitName($self);			# element
	}
}

sub visitNameElement {
	my $self = shift;
	my ($node) = @_;
	$self->_get_defn($node->{value})->visitName($self);		# single or array
}

#	3.11.2.4	Enumerations
#

sub visitNameEnumType {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);			# enum
	}
}

sub visitNameEnum {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $node->{idf};
}

#
#	3.11.3	Template Types
#
#	See	1.2.7.5		Sequences
#

sub visitNameSequenceType {
	my $self = shift;
	my ($node) = @_;
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

#
#	See	1.2.6		Primitive Types
#

sub visitNameStringType {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = "string";
	$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
}

sub visitNameWideStringType {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = "string";
	$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
}

#
#	See	1.2.7.9		Fixed
#

sub visitNameFixedPtType {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = "decimal";
	$node->{xsd_qname} = $self->{xsd} . ":" . $node->{xsd_name};
}

#
#	3.12	Exception Declaration
#
#	See	1.2.8.5		Exceptions
#

sub visitNameException {
	my $self = shift;
	my ($node) = @_;
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	foreach (@{$node->{list_value}}) {
		$self->_get_defn($_)->visitName($self);		# single or array
	}
}

#
#	3.13	Operation Declaration
#
#	See	1.2.8.2		Interface as Binding Operation
#

sub visitNameOperation {
	my $self = shift;
	my ($node) = @_;
	$self->{op} = $node->{idf};
	$node->{xsd_name} = $self->_get_name($node);
	$node->{xsd_qname} = $self->{tns} . ":" . $node->{xsd_name};
	$self->_get_defn($node->{type})->visitName($self);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

sub visitNameParameter {
	my $self = shift;
	my ($node) = @_;
	if ($self->{op} =~ /^_set_/) {
		$node->{xsd_name} = "value";
	} else {
		$node->{xsd_name} = $node->{idf};
	}
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$self->{root}->{need_corba} = 1
			if ($type->isa('BaseInterface'));
}

sub visitNameVoidType {
	# empty
}

#
#	3.14	Attribute Declaration
#

sub visitNameAttribute {
	my $self = shift;
	my ($node) = @_;
	$node->{_get}->visitName($self);
	$node->{_set}->visitName($self)
			if (exists $node->{_set});
}

#
#	3.15	Repository Identity Related Declarations
#

sub visitNameTypeId {
	# empty
}

sub visitNameTypePrefix {
	# empty
}

#
#	3.16	Event Declaration
#

sub visitRegularEvent {
	# no mapping
}

sub visitAbstractEvent {
	# no mapping
}

sub visitForwardRegularEvent {
	# no mapping
}

sub visitForwardAbstractEvent {
	# no mapping
}

#
#	3.17	Component Declaration
#

sub visitNameProvides {
	# no mapping
}

sub visitNameUses {
	# no mapping
}

sub visitNamePublishes {
	# no mapping
}

sub visitNameEmits {
	# no mapping
}

sub visitNameConsumes {
	# no mapping
}

#
#	3.18	Home Declaration
#

sub visitNameFactory {
	# no mapping
}

sub visitNameFinder {
	# no mapping
}

1;

