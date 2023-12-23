# ModuleNotFoundError: No module named '_lzma'
apt -y install liblzma-dev
pip install backports.lzma
nano /usr/local/lib/python3.9/lzma.py

### Before modification
# from _lzma import *
# from _lzma import _encode_filter_properties, _decode_filter_properties

### After modification
# try:
#     from _lzma import *
#     from _lzma import _encode_filter_properties, _decode_filter_properties
# except ImportError:
#     from backports.lzma import *
#     from backports.lzma import _encode_filter_properties, _decode_filter_properties
