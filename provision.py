"""
Server part of provisioning engine

Installation:

$ pip install falcon
$ pip install gunicorn

Start:

$ gunicorn -b 0.0.0.0:8000 provision:app

Usage: 

make sure localboot_path is correct

http GET /pxe accepts mac and unlink (true/false)

http://127.0.0.1:8000/pxe?mac=14:DA:E9:DF:B0:02 links localboot to passed mac

http://127.0.0.1:8000/pxe?mac=14:DA:E9:DF:B0:02&unlink=true unlinks

"""



import os

import falcon


localboot_path = '/tftproot/pxelinux.cfg/localboot.default'

dirname = os.path.dirname(localboot_path)


class PXEResource:
    def on_get(self, req, resp):
        """Handles GET requests"""
        mac_addr = req.get_param('mac', required=True)
        unlink = req.get_param_as_bool('unlink') or False
        dst = os.path.join(dirname, '01-' + mac_addr.lower().replace(':','-'))
        try:
            if unlink:
                os.remove(dst)
            else:
                os.symlink(localboot_path, dst)
        except:
            pass

        resp.status = falcon.HTTP_200
        resp.body = ('\n done :) %s %s \n\n' % (mac_addr, str(unlink)))

app = api = falcon.API()

pxe = PXEResource()

api.add_route('/pxe', pxe)
