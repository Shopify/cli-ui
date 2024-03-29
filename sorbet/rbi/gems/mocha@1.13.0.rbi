# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `mocha` gem.
# Please instead update this file by running `bin/tapioca gem mocha`.

::RUBY19 = T.let(T.unsafe(nil), TrueClass)

module Mocha
  class << self
    def configuration; end
    def configure; end
  end
end

module Mocha::API
  include ::Mocha::ParameterMatchers
  include ::Mocha::Hooks

  def mock(*arguments); end
  def sequence(name); end
  def states(name); end
  def stub(*arguments); end
  def stub_everything(*arguments); end

  class << self
    def extended(mod); end
    def included(_mod); end
  end
end

class Mocha::AnyInstanceMethod < ::Mocha::StubbedMethod
  private

  def method_body(method); end
  def mock_owner; end
  def original_method_owner; end
  def stubbee_method(method_name); end
end

class Mocha::AnyInstanceReceiver
  def initialize(klass); end

  def mocks; end
end

class Mocha::ArgumentIterator
  def initialize(argument); end

  def each; end
end

class Mocha::BacktraceFilter
  def initialize(lib_directory = T.unsafe(nil)); end

  def filtered(backtrace); end
end

Mocha::BacktraceFilter::LIB_DIRECTORY = T.let(T.unsafe(nil), String)
module Mocha::BlockMatchers; end

class Mocha::BlockMatchers::BlockGiven
  def match?(actual_block); end
  def mocha_inspect; end
end

class Mocha::BlockMatchers::NoBlockGiven
  def match?(actual_block); end
  def mocha_inspect; end
end

class Mocha::BlockMatchers::OptionalBlock
  def match?(_actual_block); end
  def mocha_inspect; end
end

class Mocha::Cardinality
  def initialize(required = T.unsafe(nil), maximum = T.unsafe(nil)); end

  def <<(invocation); end
  def actual_invocations; end
  def allowed_any_number_of_times?; end
  def anticipated_times; end
  def at_least(count); end
  def at_most(count); end
  def exactly(count); end
  def invocations_allowed?; end
  def invoked_times; end
  def needs_verifying?; end
  def satisfied?; end
  def times(range_or_count); end
  def used?; end
  def verified?; end

  protected

  def count(number); end
  def infinite?(number); end
  def maximum; end
  def required; end
  def update(required, maximum); end
end

Mocha::Cardinality::INFINITY = T.let(T.unsafe(nil), Float)

class Mocha::Central
  def initialize; end

  def stub(method); end
  def stubba_methods; end
  def stubba_methods=(_arg0); end
  def unstub(method); end
  def unstub_all; end
end

class Mocha::Central::Null < ::Mocha::Central
  def initialize(&block); end

  def stub(*_arg0); end
  def unstub(*_arg0); end
end

class Mocha::ChangeStateSideEffect
  def initialize(state); end

  def mocha_inspect; end
  def perform; end
end

module Mocha::ClassMethods
  def __method_exists__?(method, include_public_methods = T.unsafe(nil)); end
  def __method_visibility__(method, include_public_methods = T.unsafe(nil)); end
  def any_instance; end
end

class Mocha::ClassMethods::AnyInstance
  def initialize(klass); end

  def mocha(instantiate = T.unsafe(nil)); end
  def respond_to?(method); end
  def stubba_class; end
  def stubba_method; end
  def stubba_object; end
end

class Mocha::Configuration
  def initialize(options = T.unsafe(nil)); end

  def display_matching_invocations_on_failure=(value); end
  def display_matching_invocations_on_failure?; end
  def merge(other); end
  def reinstate_undocumented_behaviour_from_v1_9=(value); end
  def reinstate_undocumented_behaviour_from_v1_9?; end
  def stubbing_method_on_nil; end
  def stubbing_method_on_nil=(value); end
  def stubbing_method_on_non_mock_object; end
  def stubbing_method_on_non_mock_object=(value); end
  def stubbing_method_unnecessarily; end
  def stubbing_method_unnecessarily=(value); end
  def stubbing_non_existent_method; end
  def stubbing_non_existent_method=(value); end
  def stubbing_non_public_method; end
  def stubbing_non_public_method=(value); end

  protected

  def options; end

  private

  def initialize_copy(other); end

  class << self
    def allow(action, &block); end
    def allow?(action); end
    def configuration; end
    def override(temporary_options); end
    def prevent(action, &block); end
    def prevent?(action); end
    def reset_configuration; end
    def warn_when(action, &block); end
    def warn_when?(action); end

    private

    def change_config(action, new_value, &block); end
    def temporarily_change_config(action, new_value); end
  end
end

Mocha::Configuration::DEFAULTS = T.let(T.unsafe(nil), Hash)

module Mocha::Debug
  class << self
    def puts(message); end
  end
end

Mocha::Debug::OPTIONS = T.let(T.unsafe(nil), Hash)

class Mocha::DefaultName
  def initialize(mock); end

  def mocha_inspect; end
end

class Mocha::DefaultReceiver
  def initialize(mock); end

  def mocks; end
end

class Mocha::Deprecation
  class << self
    def messages; end
    def messages=(_arg0); end
    def mode; end
    def mode=(_arg0); end
    def warning(*messages); end
  end
end

module Mocha::Detection; end

module Mocha::Detection::MiniTest
  class << self
    def testcase; end
    def version; end
  end
end

class Mocha::ErrorWithFilteredBacktrace < ::StandardError
  def initialize(message = T.unsafe(nil), backtrace = T.unsafe(nil)); end
end

class Mocha::ExceptionRaiser
  def initialize(exception, message); end

  def evaluate(invocation); end
end

class Mocha::Expectation
  def initialize(mock, expected_method_name, backtrace = T.unsafe(nil)); end

  def add_in_sequence_ordering_constraint(sequence); end
  def add_ordering_constraint(ordering_constraint); end
  def add_side_effect(side_effect); end
  def at_least(minimum_number_of_times); end
  def at_least_once; end
  def at_most(maximum_number_of_times); end
  def at_most_once; end
  def backtrace; end
  def in_correct_order?; end
  def in_sequence(sequence, *sequences); end
  def inspect; end
  def invocations_allowed?; end
  def invoke(invocation); end
  def match?(invocation); end
  def matches_method?(method_name); end
  def method_signature; end
  def mocha_inspect; end
  def multiple_yields(*parameter_groups); end
  def never; end
  def once; end
  def perform_side_effects; end
  def raises(exception = T.unsafe(nil), message = T.unsafe(nil)); end
  def returns(*values); end
  def satisfied?; end
  def then(state = T.unsafe(nil)); end
  def throws(tag, object = T.unsafe(nil)); end
  def times(range); end
  def twice; end
  def used?; end
  def verified?(assertion_counter = T.unsafe(nil)); end
  def when(state_predicate); end
  def with(*expected_parameters, &matching_block); end
  def with_block_given; end
  def with_no_block_given; end
  def yields(*parameters); end
end

class Mocha::ExpectationError < ::Exception; end

class Mocha::ExpectationErrorFactory
  class << self
    def build(message = T.unsafe(nil), backtrace = T.unsafe(nil)); end
    def exception_class; end
    def exception_class=(_arg0); end
  end
end

class Mocha::ExpectationList
  def initialize(expectations = T.unsafe(nil)); end

  def +(other); end
  def add(expectation); end
  def any?; end
  def length; end
  def match(invocation); end
  def match_allowing_invocation(invocation); end
  def matches_method?(method_name); end
  def remove_all_matching_method(method_name); end
  def to_a; end
  def to_set; end
  def verified?(assertion_counter = T.unsafe(nil)); end

  private

  def matching_expectations(invocation); end
end

module Mocha::Hooks
  def mocha_setup; end
  def mocha_teardown; end
  def mocha_verify(assertion_counter = T.unsafe(nil)); end
end

class Mocha::ImpersonatingAnyInstanceName
  def initialize(klass); end

  def mocha_inspect; end
end

class Mocha::ImpersonatingName
  def initialize(object); end

  def mocha_inspect; end
end

class Mocha::InStateOrderingConstraint
  def initialize(state_predicate); end

  def allows_invocation_now?; end
  def mocha_inspect; end
end

module Mocha::Inspect; end

module Mocha::Inspect::ArrayMethods
  def mocha_inspect(wrapped = T.unsafe(nil)); end
end

module Mocha::Inspect::DateMethods
  def mocha_inspect; end
end

module Mocha::Inspect::HashMethods
  def mocha_inspect(wrapped = T.unsafe(nil)); end
end

module Mocha::Inspect::ObjectMethods
  def mocha_inspect; end
end

module Mocha::Inspect::TimeMethods
  def mocha_inspect; end
end

class Mocha::InstanceMethod < ::Mocha::StubbedMethod
  private

  def method_body(method); end
  def mock_owner; end
  def original_method_owner; end
  def stubbee_method(method_name); end
end

module Mocha::Integration; end

class Mocha::Integration::AssertionCounter
  def initialize(test_case); end

  def increment; end
end

module Mocha::Integration::MiniTest
  class << self
    def activate; end
    def translate(exception); end
  end
end

module Mocha::Integration::MiniTest::Adapter
  include ::Mocha::ParameterMatchers
  include ::Mocha::Hooks
  include ::Mocha::API

  def after_teardown; end
  def before_setup; end
  def before_teardown; end

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(_mod); end
  end
end

module Mocha::Integration::MiniTest::Nothing
  class << self
    def applicable_to?(_test_unit_version, _ruby_version = T.unsafe(nil)); end
    def description; end
    def included(_mod); end
  end
end

module Mocha::Integration::MiniTest::Version13
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version13::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version140
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version140::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version141
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version141::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version142To172
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version142To172::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version200
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version200::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version201To222
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version201To222::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version2110To2111
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version2110To2111::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version2112To320
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version2112To320::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MiniTest::Version230To2101
  include ::Mocha::API

  class << self
    def applicable_to?(mini_test_version); end
    def description; end
    def included(mod); end
  end
end

module Mocha::Integration::MiniTest::Version230To2101::RunMethodPatch
  def run(runner); end
end

module Mocha::Integration::MonkeyPatcher
  class << self
    def apply(mod, run_method_patch); end
  end
end

class Mocha::Invocation
  def initialize(mock, method_name, *arguments, &block); end

  def arguments; end
  def block; end
  def call(yield_parameters = T.unsafe(nil), return_values = T.unsafe(nil)); end
  def call_description; end
  def full_description; end
  def method_name; end
  def raised(exception); end
  def result_description; end
  def returned(value); end
  def short_call_description; end
  def threw(tag, value); end
end

class Mocha::Logger
  def initialize(io); end

  def warn(message); end
end

class Mocha::MethodMatcher
  def initialize(expected_method_name); end

  def expected_method_name; end
  def match?(actual_method_name); end
  def mocha_inspect; end
end

class Mocha::Mock
  def initialize(mockery, name = T.unsafe(nil), receiver = T.unsafe(nil)); end

  def __expectations__; end
  def __expects__(method_name_or_hash, backtrace = T.unsafe(nil)); end
  def __expire__; end
  def __singleton_class__; end
  def __stubs__(method_name_or_hash, backtrace = T.unsafe(nil)); end
  def __verified__?(assertion_counter = T.unsafe(nil)); end
  def all_expectations; end
  def any_expectations?; end
  def ensure_method_not_already_defined(method_name); end
  def everything_stubbed; end
  def expects(method_name_or_hash, backtrace = T.unsafe(nil)); end
  def inspect; end
  def method_missing(symbol, *arguments, &block); end
  def mocha_inspect; end
  def quacks_like(responder); end
  def quacks_like_instance_of(responder_class); end
  def responds_like(responder); end
  def responds_like_instance_of(responder_class); end
  def stub_everything; end
  def stubs(method_name_or_hash, backtrace = T.unsafe(nil)); end
  def unstub(*method_names); end

  private

  def check_expiry; end
  def check_responder_responds_to(symbol); end
  def raise_unexpected_invocation_error(invocation, matching_expectation); end
  def respond_to_missing?(symbol, include_private = T.unsafe(nil)); end
end

class Mocha::Mockery
  def logger; end
  def logger=(_arg0); end
  def mocha_inspect; end
  def mock_impersonating(object); end
  def mock_impersonating_any_instance_of(klass); end
  def mocks; end
  def named_mock(name); end
  def new_state_machine(name); end
  def on_stubbing(object, method); end
  def state_machines; end
  def stubba; end
  def teardown; end
  def unnamed_mock; end
  def verify(assertion_counter = T.unsafe(nil)); end

  private

  def add_mock(mock); end
  def add_state_machine(state_machine); end
  def check(action, description, signature_proc, backtrace = T.unsafe(nil)); end
  def expectations; end
  def reset; end
  def satisfied_expectations; end
  def unsatisfied_expectations; end

  class << self
    def instance; end
    def setup; end
    def teardown; end
    def verify(*args); end
  end
end

class Mocha::Mockery::Null < ::Mocha::Mockery
  def add_mock(*_arg0); end
  def add_state_machine(*_arg0); end
  def stubba; end

  private

  def raise_not_initialized_error; end
end

class Mocha::Name
  def initialize(name); end

  def mocha_inspect; end
end

class Mocha::NotInitializedError < ::Mocha::ErrorWithFilteredBacktrace; end

module Mocha::ObjectMethods
  def _method(_arg0); end
  def expects(expected_methods_vs_return_values); end
  def mocha(instantiate = T.unsafe(nil)); end
  def reset_mocha; end
  def stubba_class; end
  def stubba_method; end
  def stubba_object; end
  def stubs(stubbed_methods_vs_return_values); end
  def unstub(*method_names); end
end

class Mocha::ObjectReceiver
  def initialize(object); end

  def mocks; end
end

module Mocha::ParameterMatchers
  def Not(matcher); end
  def all_of(*matchers); end
  def any_of(*matchers); end
  def any_parameters; end
  def anything; end
  def equals(value); end
  def equivalent_uri(uri); end
  def has_entries(entries); end
  def has_entry(*options); end
  def has_key(key); end
  def has_keys(*keys); end
  def has_value(value); end
  def includes(*items); end
  def instance_of(klass); end
  def is_a(klass); end
  def kind_of(klass); end
  def optionally(*matchers); end
  def regexp_matches(regexp); end
  def responds_with(message, result); end
  def yaml_equivalent(object); end

  private

  def parse_option(option); end
end

class Mocha::ParameterMatchers::AllOf < ::Mocha::ParameterMatchers::Base
  def initialize(*matchers); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::AnyOf < ::Mocha::ParameterMatchers::Base
  def initialize(*matchers); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::AnyParameters < ::Mocha::ParameterMatchers::Base
  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::Anything < ::Mocha::ParameterMatchers::Base
  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::Base
  def &(other); end
  def to_matcher; end
  def |(other); end
end

class Mocha::ParameterMatchers::Equals < ::Mocha::ParameterMatchers::Base
  def initialize(value); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::EquivalentUri < ::Mocha::ParameterMatchers::Base
  def initialize(uri); end

  def matches?(available_parameters); end
  def mocha_inspect; end

  private

  def explode(uri); end
end

class Mocha::ParameterMatchers::HasEntries < ::Mocha::ParameterMatchers::Base
  def initialize(entries); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::HasEntry < ::Mocha::ParameterMatchers::Base
  def initialize(key, value); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::HasKey < ::Mocha::ParameterMatchers::Base
  def initialize(key); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::HasKeys < ::Mocha::ParameterMatchers::Base
  def initialize(*keys); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::HasValue < ::Mocha::ParameterMatchers::Base
  def initialize(value); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::Includes < ::Mocha::ParameterMatchers::Base
  def initialize(*items); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

module Mocha::ParameterMatchers::InstanceMethods
  def to_matcher; end
end

class Mocha::ParameterMatchers::InstanceOf < ::Mocha::ParameterMatchers::Base
  def initialize(klass); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::IsA < ::Mocha::ParameterMatchers::Base
  def initialize(klass); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::KindOf < ::Mocha::ParameterMatchers::Base
  def initialize(klass); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::Not < ::Mocha::ParameterMatchers::Base
  def initialize(matcher); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::Optionally < ::Mocha::ParameterMatchers::Base
  def initialize(*parameters); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::RegexpMatches < ::Mocha::ParameterMatchers::Base
  def initialize(regexp); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::RespondsWith < ::Mocha::ParameterMatchers::Base
  def initialize(message, result); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParameterMatchers::YamlEquivalent < ::Mocha::ParameterMatchers::Base
  def initialize(object); end

  def matches?(available_parameters); end
  def mocha_inspect; end
end

class Mocha::ParametersMatcher
  def initialize(expected_parameters = T.unsafe(nil), &matching_block); end

  def match?(actual_parameters = T.unsafe(nil)); end
  def matchers; end
  def mocha_inspect; end
  def parameters_match?(actual_parameters); end
end

Mocha::RUBY_V2_PLUS = T.let(T.unsafe(nil), TrueClass)

class Mocha::RaisedException
  def initialize(exception); end

  def mocha_inspect; end
end

class Mocha::ReturnValues
  def initialize(*values); end

  def +(other); end
  def next(invocation); end
  def values; end
  def values=(_arg0); end

  class << self
    def build(*values); end
  end
end

class Mocha::Sequence
  def initialize(name); end

  def constrain_as_next_in_sequence(expectation); end
  def mocha_inspect; end
  def satisfied_to_index?(index); end
end

class Mocha::Sequence::InSequenceOrderingConstraint
  def initialize(sequence, index); end

  def allows_invocation_now?; end
  def mocha_inspect; end
end

class Mocha::SingleReturnValue
  def initialize(value); end

  def evaluate(invocation); end
end

class Mocha::StateMachine
  def initialize(name); end

  def become(next_state_name); end
  def current_state; end
  def current_state=(_arg0); end
  def is(state_name); end
  def is_not(unexpected_state_name); end
  def mocha_inspect; end
  def name; end
  def starts_as(initial_state_name); end
end

class Mocha::StateMachine::State < ::Mocha::StateMachine::StatePredicate
  def activate; end
end

class Mocha::StateMachine::StatePredicate
  def initialize(state_machine, state, description, &active_check); end

  def active?; end
  def mocha_inspect; end
end

class Mocha::StubbedMethod
  def initialize(stubbee, method_name); end

  def ==(_arg0); end
  def define_new_method; end
  def hide_original_method; end
  def matches?(other); end
  def method_name; end
  def mock; end
  def remove_new_method; end
  def reset_mocha; end
  def restore_original_method; end
  def store_original_method; end
  def stub; end
  def stubbee; end
  def to_s; end
  def unstub; end

  private

  def remove_original_method_from_stubbee; end
  def retain_original_visibility(method_owner); end
  def store_original_method_visibility; end
  def stub_method_overwrites_original_method?; end
  def stub_method_owner; end
  def use_prepended_module_for_stub_method; end
  def use_prepended_module_for_stub_method?; end
end

class Mocha::StubbedMethod::PrependedModule < ::Module; end
class Mocha::StubbingError < ::Mocha::ErrorWithFilteredBacktrace; end

class Mocha::Thrower
  def initialize(tag, object = T.unsafe(nil)); end

  def evaluate(invocation); end
end

class Mocha::ThrownObject
  def initialize(tag, value = T.unsafe(nil)); end

  def mocha_inspect; end
end

class Mocha::YieldParameters
  def initialize; end

  def add(*parameter_groups); end
  def next_invocation; end
end

class Object < ::BasicObject
  include ::Kernel
  include ::JSON::Ext::Generator::GeneratorMethods::Object
  include ::PP::ObjectMixin
  include ::Minitest::Expectations
  include ::Mocha::ParameterMatchers::InstanceMethods
  include ::Mocha::Inspect::ObjectMethods
  include ::Mocha::ObjectMethods
end
