import os

c.JupyterHub.authenticator_class = "jupyterhub.auth.LocalAuthenticator"
c.LocalAuthenticator.create_system_users = True
c.JupyterHub.admin_users = {'ec2-user'}

c.Spawner.default_url = '/lab'
c.Spawner.cmd = ['jupyter-labhub']
