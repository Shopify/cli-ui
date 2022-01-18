# typed: ignore
# frozen_string_literal: true

module T
  class << self
    def absurd(value); end
    def all(type_a, type_b, *types); end
    def any(type_a, type_b, *types); end
    def attached_class; end
    def class_of(klass); end
    def enum(values); end
    def nilable(type); end
    def noreturn; end
    def self_type; end
    def type_alias(type = nil, &_blk); end
    def type_parameter(name); end
    def untyped; end

    def assert_type!(value, _type, _checked: true)
      value
    end

    def cast(value, _type, _checked: true)
      value
    end

    def let(value, _type, _checked: true)
      value
    end

    def must(arg, _msg = nil)
      arg
    end

    def proc
      T::Proc.new
    end

    def reveal_type(value)
      value
    end

    def unsafe(value)
      value
    end
  end

  module Sig
    def sig(arg0 = nil, &blk); end
  end

  module Helpers
    def abstract!;  end
    def interface!; end
    def final!; end
    def sealed!; end
    def mixes_in_class_methods(mod); end
  end

  module Generic
    include(T::Helpers)

    def type_parameters(*params); end
    def type_member(variance = :invariant, fixed: nil, lower: nil, upper: BasicObject); end
    def type_template(variance = :invariant, fixed: nil, lower: nil, upper: BasicObject); end

    def [](*types)
      self
    end
  end

  module Array
    def self.[](type); end
  end

  Boolean = Object.new.freeze

  module Configuration
    def self.call_validation_error_handler(signature, opts); end
    def self.call_validation_error_handler=(value); end
    def self.default_checked_level=(default_checked_level); end
    def self.enable_checking_for_sigs_marked_checked_tests; end
    def self.enable_final_checks_on_hooks; end
    def self.enable_legacy_t_enum_migration_mode; end
    def self.reset_final_checks_on_hooks; end
    def self.hard_assert_handler(str, extra); end
    def self.hard_assert_handler=(value); end
    def self.inline_type_error_handler(error); end
    def self.inline_type_error_handler=(value); end
    def self.log_info_handler(str, extra); end
    def self.log_info_handler=(value); end
    def self.scalar_types; end
    def self.scalar_types=(values); end
    # rubocop:disable Naming/InclusiveLanguage
    def self.sealed_violation_whitelist; end
    def self.sealed_violation_whitelist=(sealed_violation_whitelist); end
    # rubocop:enable Naming/InclusiveLanguage
    def self.sig_builder_error_handler(error, location); end
    def self.sig_builder_error_handler=(value); end
    def self.sig_validation_error_handler(error, opts); end
    def self.sig_validation_error_handler=(value); end
    def self.soft_assert_handler(str, extra); end
    def self.soft_assert_handler=(value); end
  end

  module Enumerable
    def self.[](type); end
  end

  module Enumerator
    def self.[](type); end
  end

  module Hash
    def self.[](keys, values); end
  end

  class Proc
    def bind(*_)
      self
    end

    def params(*_param)
      self
    end

    def void
      self
    end

    def returns(_type)
      self
    end
  end

  module Range
    def self.[](type); end
  end

  module Set
    def self.[](type); end
  end
end
