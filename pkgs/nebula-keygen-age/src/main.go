package main

import (
	"crypto/ecdh"
	"crypto/rand"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"

	"github.com/slackhq/nebula/cert"
	"golang.org/x/crypto/curve25519"
)

type helpError struct {
	s string
}

func (he *helpError) Error() string {
	return he.s
}

func newHelpErrorf(s string, v ...any) error {
	return &helpError{s: fmt.Sprintf(s, v...)}
}

func mustFlagString(name string, val *string) error {
	if *val == "" {
		return newHelpErrorf("-%s is required", name)
	}
	return nil
}

func main() {

	flag.Parse()
	args := flag.Args()

	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "Usage: %s [mode]\n\n", os.Args[0])
		os.Exit(1)
	}

	var err error

	switch args[0] {
	case "genkey":
		err = genKey(args[1:], os.Stdout, os.Stderr)
	case "sign":
		err = signCert(args[1:], os.Stdout, os.Stderr)
	default:
		err = fmt.Errorf("unknown mode: %s", args[0])
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s\n", err)
		os.Exit(1)
	}
}

type signFlags struct {
	set         *flag.FlagSet
	caKeyPath   *string
	caCertPath  *string
	name        *string
	ip          *string
	duration    *time.Duration
	inPubPath   *string
	outKeyPath  *string
	outCertPath *string
	outQRPath   *string
	groups      *string
	subnets     *string
}

func newSignFlags() *signFlags {
	sf := signFlags{set: flag.NewFlagSet("sign", flag.ContinueOnError)}
	sf.set.Usage = func() {}
	sf.caCertPath = sf.set.String("ca-crt", "ca.crt", "Optional: path to the signing CA cert")
	sf.name = sf.set.String("name", "", "Required: name of the cert, usually a hostname")
	sf.ip = sf.set.String("ip", "", "Required: ipv4 address and network in CIDR notation to assign the cert")
	sf.duration = sf.set.Duration("duration", 0, "Optional: how long the cert should be valid for. The default is 1 second before the signing cert expires. Valid time units are seconds: \"s\", minutes: \"m\", hours: \"h\"")
	sf.inPubPath = sf.set.String("in-pub", "", "Optional (if out-key not set): path to read a previously generated public key")
	sf.outKeyPath = sf.set.String("out-key", "", "Optional (if in-pub not set): path to write the private key to")
	sf.outCertPath = sf.set.String("out-crt", "", "Optional: path to write the certificate to")
	sf.groups = sf.set.String("groups", "", "Optional: comma separated list of groups")
	sf.subnets = sf.set.String("subnets", "", "Optional: comma separated list of ipv4 address and network in CIDR notation. Subnets this cert can serve for")
	return &sf
}

type keygenFlags struct {
	set        *flag.FlagSet
	outPubPath *string

	curve *string
}

func newKeygenFlags() *keygenFlags {
	cf := keygenFlags{set: flag.NewFlagSet("keygen", flag.ContinueOnError)}
	cf.set.Usage = func() {}
	cf.outPubPath = cf.set.String("out-pub", "", "Required: path to write the public key to")
	cf.curve = cf.set.String("curve", "25519", "ECDH Curve (25519, P256)")
	return &cf
}

func genKey(args []string, out io.Writer, errOut io.Writer) error {
	cf := newKeygenFlags()
	err := cf.set.Parse(args)
	if err != nil {
		return err
	}

	if err := mustFlagString("out-pub", cf.outPubPath); err != nil {
		return err
	}

	var pub, rawPriv []byte
	var curve cert.Curve
	switch *cf.curve {
	case "25519", "X25519", "Curve25519", "CURVE25519":
		pub, rawPriv = x25519Keypair()
		curve = cert.Curve_CURVE25519
	case "P256":
		pub, rawPriv = p256Keypair()
		curve = cert.Curve_P256
	default:
		return fmt.Errorf("invalid curve: %s", *cf.curve)
	}

	fmt.Fprintf(out, "%s", cert.MarshalPrivateKey(curve, rawPriv))

	err = os.WriteFile(*cf.outPubPath, cert.MarshalPublicKey(curve, pub), 0600)
	if err != nil {
		return fmt.Errorf("error while writing out-pub: %s", err)
	}

	return nil
}

func signCert(args []string, out io.Writer, errOut io.Writer) error {
	sf := newSignFlags()
	err := sf.set.Parse(args)
	if err != nil {
		return err
	}

	if err := mustFlagString("ca-crt", sf.caCertPath); err != nil {
		return err
	}
	if err := mustFlagString("name", sf.name); err != nil {
		return err
	}
	if err := mustFlagString("ip", sf.ip); err != nil {
		return err
	}
	if *sf.inPubPath != "" && *sf.outKeyPath != "" {
		return newHelpErrorf("cannot set both -in-pub and -out-key")
	}

	rawCAKey, err := io.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("error while reading ca-key: %s", err)
	}

	var curve cert.Curve
	var caKey []byte

	// naively attempt to decode the private key as though it is not encrypted
	caKey, _, curve, err = cert.UnmarshalSigningPrivateKey(rawCAKey)
	if err != nil {
		return fmt.Errorf("error while parsing ca-key: %s", err)
	}

	rawCACert, err := os.ReadFile(*sf.caCertPath)
	if err != nil {
		return fmt.Errorf("error while reading ca-crt: %s", err)
	}

	caCert, _, err := cert.UnmarshalNebulaCertificateFromPEM(rawCACert)
	if err != nil {
		return fmt.Errorf("error while parsing ca-crt: %s", err)
	}

	if err := caCert.VerifyPrivateKey(curve, caKey); err != nil {
		return fmt.Errorf("refusing to sign, root certificate does not match private key")
	}

	issuer, err := caCert.Sha256Sum()
	if err != nil {
		return fmt.Errorf("error while getting -ca-crt fingerprint: %s", err)
	}

	if caCert.Expired(time.Now()) {
		return fmt.Errorf("ca certificate is expired")
	}

	// if no duration is given, expire one second before the root expires
	if *sf.duration <= 0 {
		*sf.duration = time.Until(caCert.Details.NotAfter) - time.Second*1
	}

	ip, ipNet, err := net.ParseCIDR(*sf.ip)
	if err != nil {
		return newHelpErrorf("invalid ip definition: %s", err)
	}
	if ip.To4() == nil {
		return newHelpErrorf("invalid ip definition: can only be ipv4, have %s", *sf.ip)
	}
	ipNet.IP = ip

	groups := []string{}
	if *sf.groups != "" {
		for _, rg := range strings.Split(*sf.groups, ",") {
			g := strings.TrimSpace(rg)
			if g != "" {
				groups = append(groups, g)
			}
		}
	}

	subnets := []*net.IPNet{}
	if *sf.subnets != "" {
		for _, rs := range strings.Split(*sf.subnets, ",") {
			rs := strings.Trim(rs, " ")
			if rs != "" {
				_, s, err := net.ParseCIDR(rs)
				if err != nil {
					return newHelpErrorf("invalid subnet definition: %s", err)
				}
				if s.IP.To4() == nil {
					return newHelpErrorf("invalid subnet definition: can only be ipv4, have %s", rs)
				}
				subnets = append(subnets, s)
			}
		}
	}

	var pub, rawPriv []byte
	if *sf.inPubPath != "" {
		rawPub, err := os.ReadFile(*sf.inPubPath)
		if err != nil {
			return fmt.Errorf("error while reading in-pub: %s", err)
		}
		var pubCurve cert.Curve
		pub, _, pubCurve, err = cert.UnmarshalPublicKey(rawPub)
		if err != nil {
			return fmt.Errorf("error while parsing in-pub: %s", err)
		}
		if pubCurve != curve {
			return fmt.Errorf("curve of in-pub does not match ca")
		}
	} else {
		pub, rawPriv = newKeypair(curve)
	}

	nc := cert.NebulaCertificate{
		Details: cert.NebulaCertificateDetails{
			Name:      *sf.name,
			Ips:       []*net.IPNet{ipNet},
			Groups:    groups,
			Subnets:   subnets,
			NotBefore: time.Now(),
			NotAfter:  time.Now().Add(*sf.duration),
			PublicKey: pub,
			IsCA:      false,
			Issuer:    issuer,
			Curve:     curve,
		},
	}

	if err := nc.CheckRootConstrains(caCert); err != nil {
		return fmt.Errorf("refusing to sign, root certificate constraints violated: %s", err)
	}

	if *sf.outKeyPath == "" {
		*sf.outKeyPath = *sf.name + ".key"
	}

	if *sf.outCertPath == "" {
		*sf.outCertPath = *sf.name + ".crt"
	}

	err = nc.Sign(curve, caKey)
	if err != nil {
		return fmt.Errorf("error while signing: %s", err)
	}

	if *sf.inPubPath == "" {
		if _, err := os.Stat(*sf.outKeyPath); err == nil {
			return fmt.Errorf("refusing to overwrite existing key: %s", *sf.outKeyPath)
		}

		err = os.WriteFile(*sf.outKeyPath, cert.MarshalPrivateKey(curve, rawPriv), 0600)
		if err != nil {
			return fmt.Errorf("error while writing out-key: %s", err)
		}
	}

	b, err := nc.MarshalToPEM()
	if err != nil {
		return fmt.Errorf("error while marshalling certificate: %s", err)
	}

	err = os.WriteFile(*sf.outCertPath, b, 0600)
	if err != nil {
		return fmt.Errorf("error while writing out-crt: %s", err)
	}

	return nil
}

// func keygen(args []string, out io.Writer, errOut io.Writer) error {
// 	err := cf.set.Parse(args)
// 	if err != nil {
// 		return err
// 	}

// 	var pub, rawPriv []byte
// 	var curve cert.Curve
// 	switch *cf.curve {
// 	case "25519", "X25519", "Curve25519", "CURVE25519":
// 		pub, rawPriv = x25519Keypair()
// 		curve = cert.Curve_CURVE25519
// 	case "P256":
// 		pub, rawPriv = p256Keypair()
// 		curve = cert.Curve_P256
// 	default:
// 		return fmt.Errorf("invalid curve: %s", *cf.curve)
// 	}

// 	err = os.WriteFile(*cf.outKeyPath, cert.MarshalPrivateKey(curve, rawPriv), 0600)
// 	if err != nil {
// 		return fmt.Errorf("error while writing out-key: %s", err)
// 	}

// 	err = os.WriteFile(*cf.outPubPath, cert.MarshalPublicKey(curve, pub), 0600)
// 	if err != nil {
// 		return fmt.Errorf("error while writing out-pub: %s", err)
// 	}

// 	return nil
// }

func newKeypair(curve cert.Curve) ([]byte, []byte) {
	switch curve {
	case cert.Curve_CURVE25519:
		return x25519Keypair()
	case cert.Curve_P256:
		return p256Keypair()
	default:
		return nil, nil
	}
}

func x25519Keypair() ([]byte, []byte) {
	privkey := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, privkey); err != nil {
		panic(err)
	}

	pubkey, err := curve25519.X25519(privkey, curve25519.Basepoint)
	if err != nil {
		panic(err)
	}

	return pubkey, privkey
}

func p256Keypair() ([]byte, []byte) {
	privkey, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		panic(err)
	}
	pubkey := privkey.PublicKey()
	return pubkey.Bytes(), privkey.Bytes()
}
