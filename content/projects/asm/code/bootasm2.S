.code16
start:
    jmp     main

#===================================================================
#Main Console display functions

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen
    movb    foreground_color, %bl

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:
    ret          

#--------------------------------------------      

cons_write_crlf:
    movb    $0x0e, %ah          # Setup output char code to %ah before loop starts. Is used with int 0x10 call.
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

# Write to the screen and create new line
cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret

#--------------------------------------------

cons_write_space:
    movb    $0x0e, %ah
    movb    $0x20, %al
    int     $0x10
    ret

cons_write_debug:
    movb    $0x0e, %ah
    movb    $219, %al
    int     $0x10
    ret

# Takes char parameter in al
cons_write_char:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen
    movb    foreground_color, %bl
    int     $0x10
    ret

#--------------------------------------------

# Output the value in BX as an unsigned integer
#
# Input: BX = Value to output

cons_write_int:
    push    %bx
    push    %cx
    push    %si

    movw    $IntBuffer + 4, %si
    movw    %bx, %ax
	
cwi_getdigit:
	xor		%dx, %dx
	movw	$10, %cx
	div		%cx
	addb	$48, %dl
	movb	%dl, (%si)
	dec		%si
	cmp		$0, %ax
	jne		cwi_getdigit
	inc		%si
	call	cons_write

cwi_end:
    pop     %si
    pop     %cx
    pop     %bx
	ret
	
IntBuffer:   .string "     "

#===================================================================
#Functions for outputting a line of hex to the screen

# Display 16 bytes of data as hexidecimal
# Starts at the current address in si

cons_write_hex_line:
    push    %bx             # Store the registers we'll use
    push    %cx             
    push    %si

    movw    $8, %cx         # Prep loop over row of data

cons_write_hex_line_loop:
    movw    (%si), %dx
    rol     $8, %dx                     # Swap bytes for endian
    call    cons_write_hex
    call    cons_write_space            # Add space between hex values

    add     $2, %si                     # Displaying 2 bytes at a time so add 2 to si
    loop    cons_write_hex_line_loop    

    pop     %si
    pop     %cx
    pop     %bx
    ret

#--------------------------------------------

HexChars:	.ascii "0123456789abcdef"

# Displays character in dx as hex
# Changed from bx -> dx as bx is needed to dispay character color

cons_write_hex:
    push    %cx                     # Don't trash cx or si
    push    %si

    movw    $4, %cx                 # Prep loop
    movb    $0x0e, %ah              # Prep int call
    movb    foreground_color, %bl   # Prep character color

cons_write_hex_loop:
    rol     $4, %dx                 # roll next numbers to be displayed to the lower end of dx
    movw    %dx, %si
    and     $0x000F, %si            # Only use the lowest 4 bits
    movb    HexChars(%si), %al      # Move the character at that index in HexChars into al
    int     $0x10                   # Display that character
    loop    cons_write_hex_loop     # Repeat until 2 bytes displayed

    pop     %si                     # restore cx and si
    pop     %cx
    ret

#===================================================================
#Functions for outputting a line of ascii to the screen

# Cons Write Ascii Line (cwal)
#
# Display 16 bytes of data as ascii
# Starts at the current address in si
#
# Parameters
    #define cwal_sector_offset  4
# Local Variables
    ##define cwal_
cons_write_ascii_line:
    push    %bp
    mov     %sp, %bp

    push    %bx
    push    %cx
    push    %si

    movw    $16, %cx                    # Prep loop
    movb    $0x0e, %ah                  # Prep int 10 call
    #movb    foreground_color, %bl       # Prep character color

cwal_rpt:
    movb    (%si), %al                  # Load the byte at the location contained in the SI register into AL   
    inc     %si                         # Add 1 to the value in SI

cwal_set_color:
    push    %si
    movw    $user_search_result_array, %si
    add     cwal_sector_offset(%bp), %si
    movb    (%si), %bl                      # Move color into bl
    inc     cwal_sector_offset(%bp)         # Always increment offset into sector
    pop     %si

    cmp     $32, %al
    jge     cwal_print
    movb    $95, %al                    # Don't print ascii characters lower than 32

cwal_print:
    int     $0x10                       # Output the character in AL to the screen
    loop    cwal_rpt

    movb    $0x7, (foreground_color)    

    pop     %si
    pop     %cx
    pop     %bx

    mov     %bp, %sp
    pop     %bp
    ret     $2

#===================================================================

# Read and Display Disk Sectors (rdds)
#
# Main parent function for taking user input data and calling functions for reading
# and displaying data in chunks (via read_disk_sector and display_disk_sectors)
#
# Parameters
    #define rdds_starting_block     6
    #define rdds_sectors_to_read    4
# Local variables
    #define rdds_remaining_sectors_to_read  -2
    #define rdds_current_sectors_to_read    -4
    #define rdds_block_offset               -6

read_and_display_disk_sectors:
    push    %bp                                     # Prep stack frame
    mov     %sp, %bp
    subw    $6, %sp

    cmpw    $0, rdds_sectors_to_read(%bp)           # Check if sectors to read isn't 0
    je      rdds_end

    movw    rdds_sectors_to_read(%bp), %ax              # Init local variables
    movw    %ax, rdds_remaining_sectors_to_read(%bp)
    movw    $0, rdds_block_offset(%bp)

rdds_main_loop:
    movw    rdds_remaining_sectors_to_read(%bp), %ax    # Set current sectors to read to sectors to read
    movw    %ax, rdds_current_sectors_to_read(%bp)

    cmpw    $30, rdds_remaining_sectors_to_read(%bp)    # If sectors to read is too big, read them in chunks
    jle     rdds_read                                   # sectors to read is small enough

    movw    $30, rdds_current_sectors_to_read(%bp)      # sectors too big, read 30 this iteration

rdds_read:
    movw    rdds_current_sectors_to_read(%bp), %ax      # Subtract amount to be read from sectors to read
    subw    %ax, rdds_remaining_sectors_to_read(%bp)

    push    rdds_current_sectors_to_read(%bp)           # Push how many sectors we're reading   
    movw    rdds_starting_block(%bp), %ax               # Push the current block to read
    addw    rdds_block_offset(%bp), %ax
    push    %ax                                         # Push the starting block (starting block + offset)
    call    read_disk_sector

    push    rdds_sectors_to_read(%bp)                   # Push overall total sectors to display
    push    rdds_block_offset(%bp)                      # Push offset into sectors (total sectors processed already)
    call    display_disk_sectors                        # Uses sectors parameter from prev function

    movw    rdds_current_sectors_to_read(%bp), %ax      # Increment the starting block offset
    add     %ax, rdds_block_offset(%bp)

    cmpw    $0, rdds_remaining_sectors_to_read(%bp)     # If there are sectors still to read, loop
    jne     rdds_main_loop

rdds_end:
    mov     %bp, %sp
    pop     %bp
    ret     $4

#===================================================================

# Read Disk Sector (rds)
#
# Read a given amount of data from the disk to the pre-defined address.
#
# Pre-defined Values
    #define disk_transfer_address   $0x9000
# Parameters
    #define rds_disk_sector_count   6
    #define rds_start_block         4
read_disk_sector:
    push    %bp             # Setup Stack Frame
    mov     %sp, %bp

    push    %si             # Save si

    mov     $msg_reading_sectors, %si       # Display message whenever reading new data from disk
    call    cons_writeline

    movw    $disk_address_packet, %si           # Load disk packet address into si

    movw    rds_disk_sector_count(%bp), %ax     # Move number of sectors into disk packet
    movw    %ax, 2(%si)
    movw    disk_transfer_address, 4(%si)       # Set address to read data into
    movw    rds_start_block(%bp), %ax           # Move start block into disk packet 
    movw    %ax, 8(%si)

    movb    $0x42, %ah              # Prep read disk call
    movb    (boot_device), %dl      # Move boot device to make sure we're reading from the right disk
    int     $0x13                   # Read from disk

    jc      rds_read_failed         # Check if read success

    pop     %si                     # Restore si

    mov     %bp, %sp                # End Stack Frame
    pop     %bp
    ret     $2                      # Only remove start block parameter

rds_read_failed:
    movw 	$msg_read_failed, %si
    call    cons_writeline
    jmp     endless_loop

#===================================================================

# Display Disk Sectors (dds)
# 
# Displays all of the currently loaded sectors and displays what sector
# we're currently displaying.
#
# Parameters
    #define dds_sectors_to_read         8
    #define dds_total_sectors           6
    #define dds_sector_display_offset   4

display_disk_sectors:
    push    %bp         # Prep stack frame
    mov     %sp, %bp    # Move stack pointer into base pointer

    push    %bx         # Store used registers
    push    %cx
    push    %si

    movw    dds_sectors_to_read(%bp), %cx   # Set how many sectors to read
    movw    disk_transfer_address, %si      # Set sectors start read address
    #movw    $0x7c00, %si        # DEBUG to read through running program memory

dds_loop:
    # Output current sector message
    push    %si
    movw    $msg_sector, %si
    call    cons_write

    movw    dds_sector_display_offset(%bp), %bx     # Move offset into bx
    add     dds_sectors_to_read(%bp), %bx           # Add how many sectors we're currently displaying
    sub     %cx, %bx                                # Subtract how many loops still to go
    inc     %bx                                     # Add 1 so 0/10 -> 1/10
    call    cons_write_int                          # display sector number

    movw    $msg_out_of, %si                        # display " / "
    call    cons_write

    movw    dds_total_sectors(%bp), %bx         # Display total sectors
    call    cons_write_int

    call    cons_write_crlf                     # Make space for sector data
    call    cons_write_crlf
    pop     %si

    # Now display the current sector data
    call    scan_single_sector
    call    display_disk_single_sector          # Uses address set in si
    call    cons_write_crlf
    loop    dds_loop

dds_end:
    pop     %si     # Retrieve stored registers
    pop     %cx
    pop     %bx
    
    mov     %bp, %sp            # End stack frame
    pop     %bp
    ret     $6

#--------------------------------------------

# Scan Single Sector (sss)
# 
# Local Variables are start_index for the start of the section we're checking and
# current_index for the 
# 
# Local Variables
    #define sss_sector_start_addr       -2
    #define sss_start_index             -4
    #define sss_search_current_index    -6
    #define sss_sector_index            -8

scan_single_sector:
    push    %bp         # Prep stack frame
    mov     %sp, %bp    # Move stack pointer into base pointer
    subw    $8, %sp     # Reserve space for local variables

    push    %cx         # Don't trash si or cx
    push    %si

    cmpw    $0, UserSearchBufferLen     # Check if user entered anything to search for
    je      sss_end                     # End function if not

    movw    %si, sss_sector_start_addr(%bp)
    movw    $0, sss_start_index(%bp)        # Init local variables
    movw    $0, sss_search_current_index(%bp)
    movw    $0, sss_sector_index(%bp)

    call    clear_user_search_array

    movw    $512, %cx                   # Loop through entire sector
    #movw    $50, %cx        # DEBUG - ONLY CHECK FIRST 50 BYTES

    #jmp     sss_end                     # DEBUG

# Search functionality starts here
sss_loop:               
    push    %si
    movw    sss_search_current_index(%bp), %si
    movb    UserSearchBuffer(%si), %ah          # Get current search character we're comparing against

    #push    %ax                     # DEBUG - OUTPUT SECTOR CHARACTER
    #movb    %ah, %al                # DEBUG - OUTPUT CURRENT CHARACTER
    #call    cons_write_char         # DEBUG - OUTPUT SECTOR CHARACTER
    #pop     %ax                     # DEBUG - OUTPUT SECTOR CHARACTER

    pop     %si

    movb    (%si), %al                          # Get character in sector we're comparing against
    #push    %ax                     # DEBUG - OUTPUT SECTOR CHARACTER
    #call    cons_write_char         # DEBUG - OUTPUT SECTOR CHARACTER
    #pop     %ax                     # DEBUG - OUTPUT SECTOR CHARACTER
    cmp     %al, %ah
    je      sss_equal
    
    # NOT EQUAL CODE HERE
    
    cmp     $0, sss_search_current_index(%bp)   # Check if we're at the start of a match
    je      sss_reset_search
    # Not at start of match

    movw    sss_search_current_index(%bp), %ax  # Get how far along we were
    #dec     %ax                                 # Decrement by 1 to get the value after where we started searching
    add     %ax, %cx
    sub     %ax, %si
    sub     %ax, sss_sector_index(%bp)

sss_reset_search:
    movw    $0, sss_search_current_index(%bp)   # Reset the search index

    jmp     sss_next_loop

sss_equal:
    #jmp     sss_end                # DEBUG - end here if match
    #call    cons_write_debug       # DEBUG - print value if match

    cmp     $0, sss_search_current_index(%bp)   # Check if we're at the start of a match
    jne     sss_equal_2

    movw    sss_sector_index(%bp), %ax          # Store the start of the potential match
    movw    %ax, sss_start_index(%bp)  

sss_equal_2:
    inc     sss_search_current_index(%bp)       # Move along the search index 

    movw    sss_search_current_index(%bp), %ax  # Check if we've found the entire search phrase
    cmp     UserSearchBufferLen, %ax
    je      sss_found_match

    jmp     sss_next_loop                       # Continue the loop

sss_found_match:
    push    %si
    push    %cx

    #movw    $msg_found_a_match, %si
    #call    cons_write

    movw    $user_search_result_array, %si
    add     sss_start_index(%bp), %si
    movw    UserSearchBufferLen, %cx

sss_found_match_loop:
    movb    $0xc, (%si)                 # Set each value in array to white

    inc     %si
    loop    sss_found_match_loop

    movw    $0, sss_search_current_index(%bp)   # Reset the index into the search phrase

    pop     %cx
    pop     %si

    #jmp     sss_next_loop       # Continue the main loop

sss_next_loop:
    #movb    $0, %ah     # DEBUG - WAIT FOR USER INPUT TO CONTINUE
    #int     $0x16

    inc     %si
    inc     sss_sector_index(%bp)
    loop    sss_loop

sss_end:
    pop     %si
    pop     %cx

    #call    cons_write_crlf     # DEBUG - NEW LINE AFTER DEBUGGING TEXT

    mov     %bp, %sp
    pop     %bp
    ret

#--------------------------------------------

clear_user_search_array:
    push    %si
    movw    $user_search_result_array, %si
    movw    $512, %cx                           # Loop through entire sector

cusa_loop:
    movb    $0x7, (%si)                         # Set each value in array to white
    inc     %si
    loop    cusa_loop

    pop     %si
    ret

#--------------------------------------------

# Display Disk Single Sector (ddss)
#
# Displays a single disk sector in two parts, waiting for user input between parts.
#
# Uses pre set value in si
#
# Local variables
    #define ddss_loop_outer     -2
    #define ddss_sector_offset  -4

display_disk_single_sector:
    push    %bp                             # Prep stack frame
    mov     %sp, %bp                        # Move stack pointer into base pointer
    subw    $4, %sp                         # Reserve space for local variables

    movw    $2, ddss_loop_outer(%bp)        # Init local variables
    movw    $0, ddss_sector_offset(%bp)

    push    %cx
    push    %bx

ddss_outer_loop_start:
    movw    $16, %cx

ddss_inner_loop:
    movw    ddss_sector_offset(%bp), %dx
    call    cons_write_hex                  # Display offset into sector
    call    cons_write_space                
    int     $0x10
    int     $0x10                           # Add 3 spaces after offset hex

    call    cons_write_hex_line             # Display segment data
    push    ddss_sector_offset(%bp)
    call    cons_write_ascii_line
    call    cons_write_crlf

    add     $16, %si                        # Move to next line
    addw    $16, ddss_sector_offset(%bp)    
    loop    ddss_inner_loop

ddss_end:
    call    await_key_press                 # Wait for user input after displaying half a sector

    decw    ddss_loop_outer(%bp)
    cmpw    $0, ddss_loop_outer(%bp)        # Check if we've displayed both halves of the sector
    jg      ddss_outer_loop_start

    pop     %bx                             # Restore registers
    pop     %cx

    mov     %bp, %sp                        # End stack frame
    pop     %bp
    ret

#=============================================================================

await_key_press:
    push    %si                     # Don't trash si
    movw    $msg_press_a_key, %si    
    call    cons_write              # Print user message
    pop     %si
    movb    $0, %ah
    int     $0x16                   # Wait for user input
    call    cons_write_crlf         # Start new line
    ret

#=============================================================================

# Get User Number (gun)
#
# Get a 4 digit number from the user and returns it in a provided stack parameter
#
# Parameters
    #define gun_num_out             4

# Local variables
    #define gun_numbers_entered     -2
    #define gun_times_by            -4

get_user_number:
    push    %bp                             # Prep stack frame
    mov     %sp, %bp                        # Move stack pointer into base pointer
    subw    $4, %sp                         # Reserve space for local variables

    push    %bx                             # Store all used registers
    push    %cx

    movw    $0, gun_numbers_entered(%bp)    # Initialize local variables
    movw    $1, gun_times_by(%bp)

    movw    $msg_get_input, %si             # Prep input message
    call    cons_write                      # Display message

gun_input_loop:
    movb    $0, %ah
    int     $0x16                           # Get user input

    cmp     $48, %al                        # These checks make sure input is number
    jb      gun_char_invalid
    cmp     $57, %al
    ja      gun_char_invalid

gun_num_ok:
    call    cons_write_char                 # Display the inputted number

    movb    $0, %ah                         # Clear upper byte for later
    sub     $48, %al                        # Change from ascii to base 10
    push    %ax                             # Store for later

    incw    gun_numbers_entered(%bp)        # increment total numbers
    cmpw    $4, gun_numbers_entered(%bp)    # Check if max numbers reached
    je      gun_end                         # If so, goto end

    jmp     gun_input_loop              

gun_char_invalid:
    cmpw    $0, gun_numbers_entered(%bp)    # Don't check enter pressed if no value submitted
    je      gun_input_loop                  
    cmp     $13, %al                        # If input wasn't a number, check if it was enter pressed
    jne     gun_input_loop                  # If it wasn't enter, get next user input

gun_end:
    movw    gun_numbers_entered(%bp), %cx   # Set loop to total numbers inputted
    xorw    %bx, %bx                        # Store output in bx so clear it first

gun_end_loop:
    pop     %ax                             # Get most rescent user input

    mulw    gun_times_by(%bp)               # Multiply by either 1, 10, 100 or 1000
    add     %ax, %bx                        # Add the result to bx

    mov     $10, %ax                        
    mulw    gun_times_by(%bp)               # Times our multiplier by 10: 1 -> 10, 10 -> 100, 100 -> 1000
    mov     %ax, gun_times_by(%bp)          # Store the new multiplier

    loop    gun_end_loop                    # Loop until all user input numbers processed

    mov     %bx, gun_num_out(%bp)           # Store function output in out parameter
    call    cons_write_crlf                 # Goto new line after function done

gun_end_ret:
    pop     %cx         # Restore used registers
    pop     %bx

    mov     %bp, %sp    # End stack frame
    pop     %bp
    ret

#=============================================================================

# Get User Search (gus)
# 
# Gets a (30) length string from the user and store it in UserSearchBuffer. We also
# store the length of their input in UserSearchBufferLen.
#
# Local variables
    #define gus_chars_entered       -2
    #define gus_buffer_len          -4

UserSearchBuffer:       .string     "                              "    # setup here as length 30
UserSearchBufferLen:    .word       0

get_user_search:
    push    %bp         # Prep stack frame
    mov     %sp, %bp    # Move stack pointer into base pointer
    subw    $4, %sp     # Reserve space for local variables

    push    %si         # Store all used registers

    movw    $0, gus_chars_entered(%bp)  # Initialize local variables
    movw    $0, gus_buffer_len(%bp)

    movw    $msg_get_input, %si         # Prep input message
    call    cons_write                  # Display message

    movw    $UserSearchBuffer, %si      # move si to start of search buffer

gus_get_buffer_len:
    movb    (%si), %al                  # Move value at si memory address into al
    cmp     $0, %al                     # Check if end of buffer
    jz      gus_finish_buffer_len       
    inc     %si
    incw    gus_buffer_len(%bp)         # If not end of buffer, add 1 to length
    jmp     gus_get_buffer_len          # Keep iterating

gus_finish_buffer_len:
    movw    $UserSearchBuffer, %si      # move si to start of user input search buffer

gus_input_loop:
    movb    $0, %ah
    int     $0x16                       # Get user input

    cmp     $32, %al                    # Check if input is usable character
    jb      gus_char_invalid
    cmp     $126, %al
    ja      gus_char_invalid

gus_char_ok:                            # Inputted character is a valid ascii character
    call    cons_write_char             # Display the character

    movb    %al, (%si)                  # Add character to buffer
    inc     %si                         # Move to next empty character

    incw    gus_chars_entered(%bp)          # Keep track of total characters entered
    movw    gus_chars_entered(%bp), %ax
    cmp     gus_buffer_len(%bp), %ax        # Check if inputted characters equals max characters
    je      gus_finish                      # Finish there if so

    jmp     gus_input_loop                  # Otherwise, continue to get user input

gus_char_invalid:                       # Inputted character wasn't valid ascii character
    cmp     $13, %al                    # Check if it was the enter key pressed
    jne     gus_input_loop              # if it wasn't, continue to get user input

gus_finish:
    movw    gus_chars_entered(%bp), %ax     # Store length of user input
    movw    %ax, (UserSearchBufferLen)

    call    cons_write_crlf     # Move to new line away from used line

    pop     %si                 # Restore used registers

    mov     %bp, %sp            # End stack frame
    pop     %bp
    ret

#=============================================================================

main:
    mov     $0, %ah                 # Change to graphics mode to allow char colors
    mov     $0x10, %al
    int     $0x10

    movb    %dl, (boot_device)      # Store boot device number in case for later.
    movw    $msg_section_2, %si     # Prep section 2 boot message
    call    cons_writeline          # Display message
    call    cons_write_crlf         # Make a new line

main_loop:    
    # Get Starting Block
    movw    $msg_get_start_block, %si
    call    cons_writeline
    push    $0                      # Parameter 1 - function output
    call    get_user_number         

    # Get Sectors to read
    movw    $msg_get_sector_count, %si
    call    cons_writeline
    push    $0                      # Parameter 1 - function output
    call    get_user_number

    # Get search term
    movw    $msg_get_search_term, %si
    call    cons_writeline
    call    get_user_search

    # Display Data
    call    clear_user_search_array         # Clear the user search array (in case not initialized or used previously)
    call    read_and_display_disk_sectors   # Uses previous two "get_user_number" parameters

    # Repeat
    call    cons_write_crlf                 # Start new line and repeat process
    jmp     main_loop

    movw    $msg_end_of_program, %si        # End of bootasm2
    call    cons_writeline

endless_loop:
    #hlt
    jmp     endless_loop

#=============================================================================

# Color to make text
foreground_color:   .byte   0x7
boot_device:    .byte   0

disk_address_packet:
                    # Offset    Size    Desc
    .byte   0x10    # 0         1       Size of packet (16 bytes)
    .byte   0       # 1         1       Always 0
    .word   0       # 2         2       Number of sectors to transfer (max 127 on some BIOSes)
    .long   0       # 4         4       Transfer buffer (first 2 bytes is 16 bit offset, next 2 bytes is 16 bit sector)
    .long   0       # 8         4       Lower 32 bits of 48 bit starting LBA (starting from 0)
    .long   0       # 12        4       Upper 16 bits of 48 bit starting LBA (wll always be 0 for us)

user_search_result_array:   .fill   512

#--------------------------------------------

msg_section_2:          .string "Section 2 loaded and running."
msg_read_failed:        .string "Failed to read from disk."
msg_reading_sectors:    .string "Reading next set of sectors"

msg_get_start_block:    .string "Enter starting sector"
msg_get_sector_count:   .string "Enter sectors to read"
msg_get_search_term:    .string "Enter message to search for"
msg_get_input:          .string "Input > "
msg_press_a_key:        .string "Press a key to continue..."

msg_sector:             .string "Sector "
msg_out_of:             .string " / "

msg_end_of_program:     .string "END OF PROGRAM"

#=============================================================================