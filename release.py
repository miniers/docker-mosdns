# !/usr/bin/env python3
import argparse
import logging
import os
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("-upx", action="store_true")
parser.add_argument("-i", type=int)
args = parser.parse_args()

PROJECT_NAME = 'mosdns'
RELEASE_DIR = './release'

logger = logging.getLogger(__name__)

# more info: https://golang.org/doc/install/source
# [(env : value),(env : value)]
envs = [
    # [['GOOS', 'darwin'], ['GOARCH', 'amd64']],

    # [['GOOS', 'linux'], ['GOARCH', '386']],
    [['CGO_ENABLED','0'],['GOOS', 'linux'], ['GOARCH', 'amd64']],

    # [['GOOS', 'linux'], ['GOARCH', 'arm'], ['GOARM', '7']],
    # [['GOOS', 'linux'], ['GOARCH', 'arm64']],

    # [['GOOS', 'linux'], ['GOARCH', 'mips'], ['GOMIPS', 'hardfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mips'], ['GOMIPS', 'softfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mipsle'], ['GOMIPS', 'hardfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mipsle'], ['GOMIPS', 'softfloat']],

    # [['GOOS', 'linux'], ['GOARCH', 'mips64'], ['GOMIPS64', 'hardfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mips64'], ['GOMIPS64', 'softfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mips64le'], ['GOMIPS64', 'hardfloat']],
    # [['GOOS', 'linux'], ['GOARCH', 'mips64le'], ['GOMIPS64', 'softfloat']],

    # [['GOOS', 'freebsd'], ['GOARCH', '386']],
    # [['GOOS', 'freebsd'], ['GOARCH', 'amd64']],

    # [['GOOS', 'windows'], ['GOARCH', '386']],
    # [['GOOS', 'windows'], ['GOARCH', 'amd64']],
]


def go_build():
    logger.info(f'building {PROJECT_NAME}')

    global envs
    if args.i:
        envs = [envs[args.i]]

    VERSION = 'dev/unknown'
    try:
        VERSION = subprocess.check_output('git describe --tags --long --always', shell=True).decode().rstrip()
    except subprocess.CalledProcessError as e:
        logger.error(f'get git tag failed: {e.args}')


    for env in envs:
        os_env = os.environ.copy()  # new env

        s = PROJECT_NAME
        for pairs in env:
            os_env[pairs[0]] = pairs[1]  # add env
            s = s + '-' + pairs[1]

        suffix = ''
        bin_filename = PROJECT_NAME + suffix

        logger.info(f'building {bin_filename}')
        try:
            subprocess.check_call(
                f'go build -ldflags "-s -w -X main.version={VERSION}" -trimpath -o {bin_filename} ../', shell=True,
                env=os_env)

            if args.upx:
                try:
                    subprocess.check_call(f'upx -9 -q {bin_filename}', shell=True, stderr=subprocess.DEVNULL,
                                          stdout=subprocess.DEVNULL)
                except subprocess.CalledProcessError as e:
                    logger.error(f'upx failed: {e.args}')

        except subprocess.CalledProcessError as e:
            logger.error(f'build {bin_filename} failed: {e.args}')
        except Exception:
            logger.exception('unknown err')


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    if len(RELEASE_DIR) != 0:
        if not os.path.exists(RELEASE_DIR):
            os.mkdir(RELEASE_DIR)
        os.chdir(RELEASE_DIR)

    go_build()