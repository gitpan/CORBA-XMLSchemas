use strict;

use POSIX qw(ctime);
use XML::DOM;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#
#			CORBA to WSDL/SOAP Interworking Specification, Version 1.0 November 2003
#

use CORBA::XMLSchemas::xsd;

package CORBA::XMLSchemas::wsdlVisitor;

use base qw(CORBA::XMLSchemas::xsdVisitor);
use File::Basename;

# needs $node->{xsd_name} $node->{xsd_qname} (XsdNameVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser, $ext_schema) = @_;
	$self->{ext_schema} = $ext_schema || 'xsd';
	$self->{tns} = 'tns';
	$self->{xsd} = 'xs';
	$self->{wsdl} = 'wsdl';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{base} = $parser->YYData->{opt_b};
	my $filename = basename($self->{srcname}, ".idl") . ".wsdl";
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_inc_wsdl';
	$self->{import} = undef;
	return $self;
}

sub _import {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	unless (defined $self->{import}) {
		my $import = $self->{dom_doc}->createElement($self->{wsdl} . ":import");
		$import->setAttribute("namespace", "http://www.omg.org/IDL-Mapped");
		my $filename = $self->{srcname};
		$filename =~ s/^([^\/]+\/)+//;
		$filename =~ s/\.idl$//i;
		$filename .= '.' . $self->{ext_schema};
		$import->setAttribute("location", $self->{base} . $filename);
		$self->{import} = $import;
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

	my $definitions = $self->{dom_doc}->createElement($self->{wsdl} . ":definitions");
	$definitions->setAttribute("targetNamespace", "http://www.omg.org/IDL-Mapped");
	$definitions->setAttribute("xmlns:" . $self->{tns}, "http://www.omg.org/IDL-Mapped");
	$definitions->setAttribute("xmlns:" . $self->{xsd}, "http://www.w3.org/2001/XMLSchema");
	$definitions->setAttribute("xmlns:" . $self->{wsdl}, "http://schemas.xmlsoap.org/wsdl");
	$self->{dom_parent}->appendChild($definitions);

	my $types = $self->_types();
	$definitions->appendChild($types);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $definitions);
	}

	$definitions->insertBefore($self->{import}, $types)
			if (defined $self->{import});

	print $FH "<!-- This file was generated (by ", $0, "). DO NOT modify it -->\n";
	print $FH "<!-- From file : ", $self->{srcname}, ", ", $self->{srcname_size}, " octets, ", POSIX::ctime($self->{srcname_mtime});
	print $FH "     Generation date : ", POSIX::ctime(time());
	print $FH "-->\n";
	print $FH "\n";
	print $FH $self->_beautify($self->{dom_doc}->toString());
	print $FH "\n\n";
	print $FH "<!-- end of file : ", $self->{filename}, " -->\n";
	close $FH;
	$self->{dom_doc}->dispose();
}

sub _types {
	my $self = shift;

	my $types = $self->{dom_doc}->createElement($self->{wsdl} . ":types");

	my $schema = $self->{dom_doc}->createElement($self->{xsd} . ":schema");
	$schema->setAttribute("targetNamespace", "http://www.omg.org/IDL-Mapped");
	$schema->setAttribute("xmlns:" . $self->{xsd}, "http://www.w3.org/2001/XMLSchema");
	$schema->setAttribute("xmlns:" . $self->{tns}, "http://www.omg.org/IDL-Mapped");
	$schema->setAttribute("elementFormDefault", "qualified");
	$schema->setAttribute("attributeFormDefault", "unqualified");
	$types->appendChild($schema);

	my $simpleType = $self->{dom_doc}->createElement($self->{xsd} . ":simpleType");
	$simpleType->setAttribute("name", "CORBA.completion_status");
	$schema->appendChild($simpleType);

	my $restriction = $self->{dom_doc}->createElement($self->{xsd} . ":restriction");
	$restriction->setAttribute("base", $self->{xsd} . ":string");
	$simpleType->appendChild($restriction);

	my $enumeration = $self->{dom_doc}->createElement($self->{xsd} . ":enumeration");
	$enumeration->setAttribute("value", "COMPLETED_YES");
	$restriction->appendChild($enumeration);

	$enumeration = $self->{dom_doc}->createElement($self->{xsd} . ":enumeration");
	$enumeration->setAttribute("value", "COMPLETED_NO");
	$restriction->appendChild($enumeration);

	$enumeration = $self->{dom_doc}->createElement($self->{xsd} . ":enumeration");
	$enumeration->setAttribute("value", "COMPLETED_MAYBE");
	$restriction->appendChild($enumeration);

	my $complexType = $self->{dom_doc}->createElement($self->{xsd} . ":complexType");
	$complexType->setAttribute("name", "CORBA.SystemException");
	$schema->appendChild($complexType);

	my $sequence = $self->{dom_doc}->createElement($self->{xsd} . ":sequence");
	$complexType->appendChild($sequence);

	my $element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "minor");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{xsd} . ":unsignedInt");
	$sequence->appendChild($element);

	$element = $self->{dom_doc}->createElement($self->{xsd} . ":element");
	$element->setAttribute("name", "completion_status");
	$element->setAttribute("maxOccurs", "1");
	$element->setAttribute("minOccurs", "1");
	$element->setAttribute("type", $self->{tns} . ":CORBA.completion_status");
	$sequence->appendChild($element);

	return $types;
}

#
#	3.8		Interface Declaration
#
#	See 1.2.8		Interfaces
#

sub visitRegularInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $str = " interface: " . $node->{xsd_name} . " ";
	my $comment = $self->{dom_doc}->createComment($str);
	$dom_parent->appendChild($comment);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}

	if (scalar keys %{$node->{hash_attribute_operation}}) {
		my $str = " port for " . $node->{xsd_name} . " ";
		my $comment = $self->{dom_doc}->createComment($str);
		$dom_parent->appendChild($comment);

		my $portType = $self->{dom_doc}->createElement($self->{wsdl} . ":portType");
		$portType->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($portType);

		foreach (values %{$node->{hash_attribute_operation}}) {
			my $defn = $self->_get_defn($_);
			if ($defn->isa('Operation')) {
				$self->_operation($defn, $portType, $node->{xsd_name});
			} else {
				$self->_operation($defn->{_get}, $portType, $node->{xsd_name});
				$self->_operation($defn->{_set}, $portType, $node->{xsd_name})
						if (exists $defn->{_set});
			}
		}
	}
}

sub _operation {
	my $self = shift;
	my ($node, $dom_parent, $itf) = @_;

	my $operation = $self->{dom_doc}->createElement($self->{wsdl} . ":operation");
	$operation->setAttribute("name", $node->{idf});
	$dom_parent->appendChild($operation);

	if (scalar(@{$node->{list_in}}) + scalar(@{$node->{list_inout}})) {
		my $input = $self->{dom_doc}->createElement($self->{wsdl} . ":input");
		$input->setAttribute("message", $self->{tns} . ":" . $itf . "." . $node->{idf});
		$operation->appendChild($input);
	}

	my $type = $self->_get_defn($node->{type});
	if (scalar(@{$node->{list_inout}}) + scalar(@{$node->{list_out}})
			or ! $type->isa('VoidType') ) {
		my $output = $self->{dom_doc}->createElement($self->{wsdl} . ":output");
		$output->setAttribute("message", $self->{tns} . ":" . $itf . "." . $node->{idf} . "Response");
		$operation->appendChild($output);
	}

	foreach (@{$node->{list_raise}}) {
		my $defn = $self->_get_defn($_);

		my $fault = $self->{dom_doc}->createElement($self->{wsdl} . ":fault");
		$fault->setAttribute("message", $self->{tns} . ":_exception." . $defn->{xsd_name});
		$operation->appendChild($fault);
	}

	unless (exists $node->{modifier}) {
		my $fault = $self->{dom_doc}->createElement($self->{wsdl} . ":fault");
		$fault->setAttribute("message", $self->{tns} . ":CORBA.SystemException");
		$operation->appendChild($fault);
	}
}

sub visitAbstractInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $str = " abstract interface: " . $node->{xsd_name} . " ";
	my $comment = $self->{dom_doc}->createComment($str);
	$dom_parent->appendChild($comment);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $dom_parent);
	}
}

#
#	3.9		Value Declaration
#

sub visitValue {
	shift->_import(@_);
}

#
#	3.11	Type Declaration
#

sub visitTypeDeclarator {
	shift->_import(@_);
}

sub visitStructType {
	shift->_import(@_);
}


sub visitUnionType {
	shift->_import(@_);
}

sub visitEnumType {
	shift->_import(@_);
}

#
#	3.12	Exception Declaration
#

sub visitException {
	shift->_import(@_);
}

#
#	3.13	Operation Declaration
#
#	See	1.2.8.2		Interface as Binding Operations
#

sub visitOperation {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	if (scalar(@{$node->{list_in}}) + scalar(@{$node->{list_inout}})) {
		my $message = $self->{dom_doc}->createElement($self->{wsdl} . ":message");
		$message->setAttribute("name", $node->{xsd_name});
		$dom_parent->appendChild($message);

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'in'
					or $_->{attr} eq 'inout' ) {
				$_->visit($self, $message);		# parameter
			}
		}
	}

	my $type = $self->_get_defn($node->{type});
	if (scalar(@{$node->{list_inout}}) + scalar(@{$node->{list_out}})
			or ! $type->isa('VoidType') ) {
		my $message = $self->{dom_doc}->createElement($self->{wsdl} . ":message");
		$message->setAttribute("name", $node->{xsd_name} . "Response");
		$dom_parent->appendChild($message);

		unless ($type->isa("VoidType")) {
			my $part = $self->{dom_doc}->createElement("part");
			$part->setAttribute("name", "_return");
			$part->setAttribute("type", $type->{xsd_qname});
			$message->appendChild($part);
		}

		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'inout'
					or $_->{attr} eq 'out' ) {
				$_->visit($self, $message);		# parameter
			}
		}
	}

	foreach (@{$node->{list_raise}}) {
		my $defn = $self->_get_defn($_);

		my $message = $self->{dom_doc}->createElement($self->{wsdl} . ":message");
		$message->setAttribute("name", "_exception." . $defn->{xsd_name});
		$dom_parent->appendChild($message);

		my $part = $self->{dom_doc}->createElement("part");
		$part->setAttribute("name", "exception");
		$part->setAttribute("type", $defn->{xsd_qname});
		$message->appendChild($part);
	}
}

sub visitParameter {
	my $self = shift;
	my ($node, $dom_parent) = @_;
	my $type = $self->_get_defn($node->{type});

	my $part = $self->{dom_doc}->createElement($self->{wsdl} . ":part");
	$part->setAttribute("name", $node->{xsd_name});
	$part->setAttribute("type", $type->{xsd_qname});
	$dom_parent->appendChild($part);
}

##############################################################################

package CORBA::XMLSchemas::wsdlSoapBindingVisitor;

use base qw(CORBA::XMLSchemas::xsdVisitor);
use File::Basename;

# needs $node->{xsd_name} $node->{xsd_qname} (XsdNameVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser) = @_;
	$self->{tns} = 'tns';
	$self->{wsdl} = 'wsdl';
	$self->{soap} = 'soap';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{base} = $parser->YYData->{opt_b};
	my $filename = basename($self->{srcname}, ".idl") . "binding.wsdl";
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_inc_soap';
	return $self;
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

	my $definitions = $self->{dom_doc}->createElement($self->{wsdl} . ":definitions");
	$definitions->setAttribute("targetNamespace", "http://www.omg.org/IDL-Mapped");
	$definitions->setAttribute("xmlns:" . $self->{tns}, "http://www.omg.org/IDL-Mapped");
	$definitions->setAttribute("xmlns:" . $self->{wsdl}, "http://schemas.xmlsoap.org/wsdl");
	$definitions->setAttribute("xmlns:" . $self->{soap}, "http://schemas.xmlsoap.org/wsdl/soap");
	$self->{dom_parent}->appendChild($definitions);

	my $import = $self->{dom_doc}->createElement($self->{wsdl} . ":import");
	$import->setAttribute("namespace", "http://www.omg.org/IDL-Mapped");
	my $filename = $self->{srcname};
	$filename =~ s/^([^\/]+\/)+//;
	$filename =~ s/\.idl$//i;
	$filename .= '.wsdl';
	$import->setAttribute("location", $self->{base} . $filename);
	$definitions->appendChild($import);

	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self, $definitions);
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

#
#	3.8		Interface Declaration
#
#	See 1.2.8		Interfaces
#

sub visitBaseInterface {
	# empty
}

sub visitRegularInterface {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $binding = $self->{dom_doc}->createElement($self->{wsdl} . ":binding");
	$binding->setAttribute("name", $node->{xsd_name} .  "Binding");
	$binding->setAttribute("type", $node->{xsd_name});
	$dom_parent->appendChild($binding);

	my $soap_binding = $self->{dom_doc}->createElement($self->{soap} . ":binding");
	$soap_binding->setAttribute("style", "rpc");
	$soap_binding->setAttribute("transport", "http://schemas.xmlsoap.org/soap/http");
	$binding->appendChild($soap_binding);

	$self->{itf} = $node->{xsd_name};
	foreach (values %{$node->{hash_attribute_operation}}) {
		$self->_get_defn($_)->visit($self, $binding);
	}
	delete $self->{itf};
}

#
#	3.9		Value Declaration
#

#
#	3.11	Type Declaration
#

sub visitTypeDeclarator {
	# empty
}

sub visitStructType {
	# empty
}


sub visitUnionType {
	# empty
}

sub visitEnumType {
	# empty
}

#
#	3.12	Exception Declaration
#

sub visitException {
	# empty
}

#
#	3.13	Operation Declaration
#
#	See	1.2.8.2		Interface as Binding Operations
#

sub visitOperation {
	my $self = shift;
	my ($node, $dom_parent) = @_;

	my $operation = $self->{dom_doc}->createElement($self->{wsdl} . ":operation");
	$operation->setAttribute("name", $node->{idf});
	$dom_parent->appendChild($operation);

	my $soap_operation = $self->{dom_doc}->createElement($self->{soap} . ":operation");
	$soap_operation->setAttribute("soapAction", $self->{itf} . "#" . $node->{idf});
	$operation->appendChild($soap_operation);

	if (scalar(@{$node->{list_in}}) + scalar(@{$node->{list_inout}})) {
		my $input = $self->{dom_doc}->createElement($self->{wsdl} . ":input");
		$operation->appendChild($input);

		my $soap_body = $self->{dom_doc}->createElement($self->{soap} . ":body");
		$soap_body->setAttribute("namespace", $self->{itf});
		$soap_body->setAttribute("use", "literal");
		$input->appendChild($soap_body);
	}

	my $type = $self->_get_defn($node->{type});
	if (scalar(@{$node->{list_inout}}) + scalar(@{$node->{list_out}})
			or ! $type->isa('VoidType') ) {
		my $output = $self->{dom_doc}->createElement($self->{wsdl} . ":output");
		$operation->appendChild($output);

		my $soap_body = $self->{dom_doc}->createElement($self->{soap} . ":body");
		$soap_body->setAttribute("namespace", $self->{itf});
		$soap_body->setAttribute("use", "literal");
		$output->appendChild($soap_body);
	}

	foreach (@{$node->{list_raise}}) {
		my $defn = $self->_get_defn($_);

		my $fault = $self->{dom_doc}->createElement($self->{wsdl} . ":fault");
		$operation->appendChild($fault);

		my $soap_body = $self->{dom_doc}->createElement($self->{soap} . ":body");
		$soap_body->setAttribute("namespace", $self->{itf});
		$soap_body->setAttribute("use", "literal");
		$fault->appendChild($soap_body);
	}

	unless (exists $node->{modifier}) {
		my $fault = $self->{dom_doc}->createElement($self->{wsdl} . ":fault");
		$fault->setAttribute("message", $self->{tns} . ":CORBA.SystemException");
		$operation->appendChild($fault);
	}
}

1;

