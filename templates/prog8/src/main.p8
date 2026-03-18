; {{PROJECT_NAME}} - Commander X16 Prog8 Program
; Created: {{DATE}}

%import textio
%zeropage basicsafe

main {
    sub start() {
        txt.clear_screen()
        txt.print("hello from {{PROJECT_NAME}}!\n")
        txt.print("commander x16 - 65c02 @ 8mhz\n")
        txt.print("press any key...\n")

        repeat {
            cx16.r0L = cbm.GETIN()
            if cx16.r0L != 0
                break
        }
    }
}
