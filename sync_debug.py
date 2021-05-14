import sys
import ps_core

if __name__ == '__main__':
    smtp_config = ps_core.init(sys.argv[1])
    ps_core.main_sync()
    ps_core.de_init()
