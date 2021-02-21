;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Nintendo 64 RDP include file
;; Part of the naken_asm assembler
;;
;; Generated by: Michael Kohn (mike@mikekohn.net)
;;         From: RSP Programmer's Guide
;;         Date: 2021-Feb-21
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; RDP: Reality Display Processor (Rasterizer Interface)

DP_BASE        equ 0x04100000

DP_START_REG   equ 0x00
DP_END_REG     equ 0x04
DP_CURRENT_REG equ 0x08
DP_STATUS_REG  equ 0x0c
DP_CLOCK_REG   equ 0x10
DP_BUFBUSY_REG equ 0x14
DP_PIPE_REG    equ 0x18
DP_TMEM_REG    equ 0x1c

DP_READ_STATUS_DMEM_DMA            equ 0x001
DP_READ_STATUS_FREEZE              equ 0x002
DP_READ_STATUS_FLUSH               equ 0x004
DP_READ_STATUS_START_GCLK          equ 0x008
DP_READ_STATUS_TMEM_BUSY           equ 0x010
DP_READ_STATUS_PIPE_BUSY           equ 0x020
DP_READ_STATUS_COMMAND_BUSY        equ 0x040
DP_READ_STATUS_COMMAND_BUFFER_BUSY equ 0x080
DP_READ_STATUS_DMA_BUSY            equ 0x100
DP_READ_STATUS_END_VALID           equ 0x200
DP_READ_STATUS_START_VALID         equ 0x400

DP_WRITE_STATUS_CLEAR_DMEM_DMA_MODE   equ 0x001
DP_WRITE_STATUS_SET_DMEM_DMA_MODE     equ 0x002
DP_WRITE_STATUS_CLEAR_FREEZE          equ 0x004
DP_WRITE_STATUS_SET_FREEZE            equ 0x008
DP_WRITE_STATUS_CLEAR_FLUSH           equ 0x010
DP_WRITE_STATUS_SET_FLUSH             equ 0x020
DP_WRITE_STATUS_CLEAR_TEMEM_COUNTER   equ 0x040
DP_WRITE_STATUS_CLEAR_PIPE_COUNTER    equ 0x080
DP_WRITE_STATUS_CLEAR_COMMAND_COUNTER equ 0x100
DP_WRITE_STATUS_CLEAR_CLOCK_COUNTER   equ 0x200

;; Rasterizer Command Set
DP_OPCODE_SET_COLOR_IMAGE   equ 0x3f
DP_OPCODE_SET_TEXTURE_IMAGE equ 0x3d
DP_OPCODE_SET_Z_IMAGE       equ 0x3e
DP_OPCODE_SET_OTHER_MODES   equ 0x2f
DP_OPCODE_SET_TILE          equ 0x35
DP_OPCODE_LOAD_TILE         equ 0x34
DP_OPCODE_SET_FILL_COLOR    equ 0x37
DP_OPCODE_FILL_RECTANGLE    equ 0x36
DP_OPCODE_TEXTURE_RECTANGLE equ 0x24
DP_OPCODE_SYNC_LOAD         equ 0x31
DP_OPCODE_SYNC_TILE         equ 0x28
DP_OPCODE_SYNC_PIPE         equ 0x27
DP_OPCODE_SYNC_FULL         equ 0x29
