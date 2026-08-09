module polymorphic_ownership_refusal_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: holder_t, replace_holder, clear_holder, evaluate_owned

    type, abstract :: node_t
        real(dp) :: bias = 0.0_dp
    contains
        procedure(node_value), deferred, pass(self) :: value
    end type node_t

    abstract interface
        pure function node_value(self, x) result(y)
            import :: dp, node_t
            class(node_t), intent(in) :: self
            real(dp), intent(in) :: x
            real(dp) :: y
        end function node_value
    end interface

    type, extends(node_t) :: linear_node_t
        real(dp) :: slope = 0.0_dp
    contains
        procedure, pass(self) :: value => linear_value
    end type linear_node_t

    type, extends(node_t) :: quadratic_node_t
        real(dp) :: slope = 0.0_dp
        real(dp) :: curvature = 0.0_dp
    contains
        procedure, pass(self) :: value => quadratic_value
    end type quadratic_node_t

    type :: holder_t
        class(node_t), allocatable :: node
        integer :: generation = 0
    contains
        final :: finalize_holder
    end type holder_t

contains

    pure function linear_value(self, x) result(y)
        class(linear_node_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%slope*x + self%bias
    end function linear_value

    pure function quadratic_value(self, x) result(y)
        class(quadratic_node_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%curvature*x*x + self%slope*x + self%bias
    end function quadratic_value

    subroutine replace_holder(holder, kind, slope, curvature, bias)
        type(holder_t), intent(inout) :: holder
        integer, intent(in) :: kind
        real(dp), intent(in) :: slope, curvature, bias
        class(node_t), allocatable :: incoming

        select case (kind)
        case (1)
            allocate(linear_node_t :: incoming)
            select type (incoming)
            type is (linear_node_t)
                incoming%slope = slope
                incoming%bias = bias
            end select
        case (2)
            allocate(quadratic_node_t :: incoming)
            select type (incoming)
            type is (quadratic_node_t)
                incoming%slope = slope
                incoming%curvature = curvature
                incoming%bias = bias
            end select
        case default
            error stop "unknown node kind"
        end select

        call move_alloc(incoming, holder%node)
        holder%generation = holder%generation + 1
    end subroutine replace_holder

    subroutine clear_holder(holder)
        type(holder_t), intent(inout) :: holder

        if (allocated(holder%node)) deallocate(holder%node)
        holder%generation = holder%generation + 1
    end subroutine clear_holder

    function evaluate_owned(holder, x) result(y)
        type(holder_t), intent(in) :: holder
        real(dp), intent(in) :: x
        real(dp) :: y

        if (.not. allocated(holder%node)) then
            y = 0.0_dp
        else
            y = holder%node%value(x) + real(holder%generation, dp)
        end if
    end function evaluate_owned

    subroutine finalize_holder(holder)
        type(holder_t), intent(inout) :: holder

        if (allocated(holder%node)) deallocate(holder%node)
    end subroutine finalize_holder

end module polymorphic_ownership_refusal_kernel
