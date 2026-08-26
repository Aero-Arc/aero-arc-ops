package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	agentv1 "github.com/aero-arc/aero-arc-protos/gen/go/aeroarc/agent/v1"
	conformancev1 "github.com/aero-arc/aero-arc-protos/gen/go/aeroarc/conformance/v1"
	relayv1 "github.com/aero-arc/aero-arc-protos/gen/go/aeroarc/relay/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type sharedFlags struct {
	caFile     string
	certFile   string
	keyFile    string
	serverName string
	timeout    time.Duration
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "sitl control:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("expected activate, set-context, clear, or aircraft-command")
	}
	switch args[0] {
	case "activate":
		return activate(args[1:])
	case "set-context":
		return setContext(args[1:])
	case "clear":
		return clearContext(args[1:])
	case "aircraft-command":
		return aircraftCommand(args[1:])
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func setContext(args []string) error {
	fs := flag.NewFlagSet("set-context", flag.ContinueOnError)
	var shared sharedFlags
	addSharedFlags(fs, &shared)
	relayAddress := fs.String("relay", "127.0.0.1:50050", "Relay gRPC address")
	agentID := fs.String("agent-id", "", "agent ID")
	flightID := fs.String("flight-id", "", "flight ID")
	intentID := fs.String("intent-id", "", "intent ID")
	intentVersion := fs.Uint("intent-version", 1, "intent version")
	commandID := fs.String("command-id", "", "idempotency key")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := require(map[string]string{
		"agent-id": *agentID, "flight-id": *flightID, "intent-id": *intentID,
		"command-id": *commandID,
	}); err != nil {
		return err
	}
	if *intentVersion == 0 {
		return errors.New("intent-version must be positive")
	}
	creds, err := clientCredentials(shared)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), shared.timeout)
	defer cancel()
	conn, err := grpc.NewClient(*relayAddress, grpc.WithTransportCredentials(creds))
	if err != nil {
		return fmt.Errorf("connect to Relay: %w", err)
	}
	defer conn.Close()
	result, err := relayv1.NewRelayControlClient(conn).SetOperationContext(ctx, &relayv1.SetOperationContextRequest{
		AgentId: *agentID,
		Command: &agentv1.SetOperationContextCommand{
			CommandId: *commandID,
			Context: &agentv1.OperationContext{
				FlightId: *flightID, IntentId: *intentID,
				IntentVersion: uint32(*intentVersion),
			},
		},
	})
	if err != nil {
		return fmt.Errorf("set Agent operation context: %w", err)
	}
	if !acceptedAck(result.GetResult().GetStatus()) {
		return fmt.Errorf("Agent rejected operation context: %s: %s", result.GetResult().GetStatus(), result.GetResult().GetError())
	}
	fmt.Printf("Agent context set for flight %s\n", *flightID)
	return nil
}

func addSharedFlags(fs *flag.FlagSet, values *sharedFlags) {
	fs.StringVar(&values.caFile, "ca", "", "control-plane CA certificate")
	fs.StringVar(&values.certFile, "cert", "", "control-plane client certificate")
	fs.StringVar(&values.keyFile, "key", "", "control-plane client private key")
	fs.StringVar(&values.serverName, "server-name", "localhost", "TLS server name")
	fs.DurationVar(&values.timeout, "timeout", 15*time.Second, "RPC deadline")
}

func activate(args []string) error {
	fs := flag.NewFlagSet("activate", flag.ContinueOnError)
	var shared sharedFlags
	addSharedFlags(fs, &shared)
	conformanceAddress := fs.String("conformance", "127.0.0.1:50052", "Conformance gRPC address")
	relayAddress := fs.String("relay", "127.0.0.1:50050", "Relay gRPC address")
	assignmentID := fs.String("assignment-id", "", "assignment ID")
	generation := fs.Uint64("generation", 1, "assignment generation")
	operatorID := fs.String("operator-id", "", "operator ID")
	aircraftID := fs.String("aircraft-id", "", "aircraft ID")
	agentID := fs.String("agent-id", "", "agent ID")
	flightID := fs.String("flight-id", "", "flight ID")
	intentID := fs.String("intent-id", "", "intent ID")
	intentVersion := fs.Uint("intent-version", 1, "intent version")
	volumeID := fs.String("volume-id", "", "volume ID")
	plannedStartValue := fs.String("planned-start", "", "RFC3339 planned start")
	plannedEndValue := fs.String("planned-end", "", "RFC3339 planned end")
	monitorUntilValue := fs.String("monitor-until", "", "RFC3339 monitoring authority end")
	latitude := fs.Float64("latitude", -35.363262, "SITL home latitude")
	longitude := fs.Float64("longitude", 149.165237, "SITL home longitude")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := require(map[string]string{
		"assignment-id": *assignmentID, "operator-id": *operatorID, "aircraft-id": *aircraftID,
		"agent-id": *agentID, "flight-id": *flightID, "intent-id": *intentID,
		"volume-id": *volumeID, "planned-start": *plannedStartValue,
		"planned-end": *plannedEndValue, "monitor-until": *monitorUntilValue,
	}); err != nil {
		return err
	}
	plannedStart, err := time.Parse(time.RFC3339Nano, *plannedStartValue)
	if err != nil {
		return fmt.Errorf("parse planned start: %w", err)
	}
	plannedEnd, err := time.Parse(time.RFC3339Nano, *plannedEndValue)
	if err != nil {
		return fmt.Errorf("parse planned end: %w", err)
	}
	monitorUntil, err := time.Parse(time.RFC3339Nano, *monitorUntilValue)
	if err != nil {
		return fmt.Errorf("parse monitor until: %w", err)
	}
	if !plannedStart.Before(plannedEnd) || monitorUntil.Before(plannedEnd) {
		return errors.New("planned start must precede planned end, and monitoring authority must not end before the plan")
	}
	creds, err := clientCredentials(shared)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), shared.timeout)
	defer cancel()
	conformanceConn, err := grpc.NewClient(*conformanceAddress, grpc.WithTransportCredentials(creds))
	if err != nil {
		return fmt.Errorf("connect to Conformance: %w", err)
	}
	defer conformanceConn.Close()
	assignment := &conformancev1.Assignment{
		AssignmentId: *assignmentID, AssignmentGeneration: *generation,
		OperatorId: *operatorID, AircraftId: *aircraftID, AgentId: *agentID,
		FlightId: *flightID, IntentId: *intentID, IntentVersion: uint32(*intentVersion),
		PolicyVersion: "standard-v1", EffectiveFrom: timestamppb.New(plannedStart),
		EffectiveUntil: timestamppb.New(monitorUntil),
		Volumes: []*conformancev1.ConformanceVolume{{
			VolumeId: *volumeID, AltitudeLowerM: 0, AltitudeUpperM: 1000,
			AltitudeReference: conformancev1.AltitudeReference_ALTITUDE_REFERENCE_MSL,
			StartsAt:          timestamppb.New(plannedStart), EndsAt: timestamppb.New(plannedEnd),
			Polygon: square(*latitude, *longitude, 0.01),
		}},
	}
	client := conformancev1.NewConformanceServiceClient(conformanceConn)
	prefix := fmt.Sprintf("sitl-%s-%d", *assignmentID, *generation)
	prepared, err := client.PrepareAssignment(ctx, &conformancev1.PrepareAssignmentRequest{Source: "sitl-observer", MessageId: prefix + "-prepare", Assignment: assignment})
	if err != nil {
		return fmt.Errorf("prepare assignment: %w", err)
	}
	if !acceptedDisposition(prepared.GetDisposition()) {
		return fmt.Errorf("prepare assignment disposition: %s", prepared.GetDisposition())
	}
	armed, err := client.ArmAssignment(ctx, &conformancev1.ArmAssignmentRequest{Source: "sitl-observer", MessageId: prefix + "-arm", AssignmentId: *assignmentID, AssignmentGeneration: *generation})
	if err != nil {
		return fmt.Errorf("arm assignment: %w", err)
	}
	if !acceptedDisposition(armed.GetDisposition()) {
		return fmt.Errorf("arm assignment disposition: %s", armed.GetDisposition())
	}
	cutoverAt := time.Now().UTC()
	cutover, err := client.CutoverAssignment(ctx, &conformancev1.CutoverAssignmentRequest{Source: "sitl-observer", MessageId: prefix + "-cutover", AssignmentId: *assignmentID, AssignmentGeneration: *generation, EffectiveAt: timestamppb.New(cutoverAt)})
	if err != nil {
		return fmt.Errorf("cut over assignment: %w", err)
	}
	if !acceptedDisposition(cutover.GetDisposition()) || cutover.GetAssignment().GetLifecycle() != conformancev1.AssignmentLifecycle_ASSIGNMENT_LIFECYCLE_ACTIVE {
		return fmt.Errorf("cutover did not activate assignment: %s / %s", cutover.GetDisposition(), cutover.GetAssignment().GetLifecycle())
	}
	relayConn, err := grpc.NewClient(*relayAddress, grpc.WithTransportCredentials(creds))
	if err != nil {
		return fmt.Errorf("connect to Relay: %w", err)
	}
	defer relayConn.Close()
	result, err := relayv1.NewRelayControlClient(relayConn).SetOperationContext(ctx, &relayv1.SetOperationContextRequest{
		AgentId: *agentID,
		Command: &agentv1.SetOperationContextCommand{CommandId: prefix + "-set-context", Context: &agentv1.OperationContext{FlightId: *flightID, IntentId: *intentID, IntentVersion: uint32(*intentVersion)}},
	})
	if err != nil {
		return fmt.Errorf("set Agent operation context: %w", err)
	}
	if !acceptedAck(result.GetResult().GetStatus()) {
		return fmt.Errorf("Agent rejected operation context: %s: %s", result.GetResult().GetStatus(), result.GetResult().GetError())
	}
	fmt.Printf("assignment %s/%d active; Agent context set for flight %s\n", *assignmentID, *generation, *flightID)
	return nil
}

func clearContext(args []string) error {
	fs := flag.NewFlagSet("clear", flag.ContinueOnError)
	var shared sharedFlags
	addSharedFlags(fs, &shared)
	relayAddress := fs.String("relay", "127.0.0.1:50050", "Relay gRPC address")
	agentID := fs.String("agent-id", "", "agent ID")
	flightID := fs.String("flight-id", "", "flight ID")
	commandID := fs.String("command-id", "", "idempotency key")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := require(map[string]string{"agent-id": *agentID, "flight-id": *flightID, "command-id": *commandID}); err != nil {
		return err
	}
	creds, err := clientCredentials(shared)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), shared.timeout)
	defer cancel()
	conn, err := grpc.NewClient(*relayAddress, grpc.WithTransportCredentials(creds))
	if err != nil {
		return err
	}
	defer conn.Close()
	result, err := relayv1.NewRelayControlClient(conn).ClearOperationContext(ctx, &relayv1.ClearOperationContextRequest{AgentId: *agentID, Command: &agentv1.ClearOperationContextCommand{CommandId: *commandID, FlightId: *flightID}})
	if err != nil {
		return fmt.Errorf("clear Agent operation context: %w", err)
	}
	if !acceptedAck(result.GetResult().GetStatus()) {
		return fmt.Errorf("Agent rejected clear: %s: %s", result.GetResult().GetStatus(), result.GetResult().GetError())
	}
	fmt.Printf("Agent context cleared for flight %s\n", *flightID)
	return nil
}

func aircraftCommand(args []string) error {
	fs := flag.NewFlagSet("aircraft-command", flag.ContinueOnError)
	var shared sharedFlags
	addSharedFlags(fs, &shared)
	relayAddress := fs.String("relay", "127.0.0.1:50050", "Relay gRPC address")
	agentID := fs.String("agent-id", "", "agent ID")
	aircraftID := fs.String("aircraft-id", "", "aircraft ID")
	commandID := fs.String("command-id", "", "command ID")
	action := fs.String("action", "", "arm or disarm")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := require(map[string]string{"agent-id": *agentID, "aircraft-id": *aircraftID, "command-id": *commandID, "action": *action}); err != nil {
		return err
	}
	commandType := agentv1.AircraftCommandType_AIRCRAFT_COMMAND_TYPE_UNSPECIFIED
	switch strings.ToLower(*action) {
	case "arm":
		commandType = agentv1.AircraftCommandType_AIRCRAFT_COMMAND_TYPE_ARM
	case "disarm":
		commandType = agentv1.AircraftCommandType_AIRCRAFT_COMMAND_TYPE_DISARM
	default:
		return errors.New("action must be arm or disarm")
	}
	creds, err := clientCredentials(shared)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), shared.timeout)
	defer cancel()
	conn, err := grpc.NewClient(*relayAddress, grpc.WithTransportCredentials(creds))
	if err != nil {
		return err
	}
	defer conn.Close()
	result, err := relayv1.NewRelayControlClient(conn).SendAircraftCommand(ctx, &relayv1.SendAircraftCommandRequest{AgentId: *agentID, Command: &agentv1.AircraftCommand{CommandId: *commandID, AircraftId: *aircraftID, Type: commandType, IssuedAtUnixMs: time.Now().UnixMilli()}})
	if err != nil {
		return fmt.Errorf("send aircraft command: %w", err)
	}
	if result.GetResult().GetStatus() != agentv1.AircraftCommandResult_STATUS_ACCEPTED {
		return fmt.Errorf("aircraft command %s: %s", result.GetResult().GetStatus(), result.GetResult().GetMessage())
	}
	fmt.Printf("aircraft %s accepted %s command\n", *aircraftID, strings.ToLower(*action))
	return nil
}

func clientCredentials(values sharedFlags) (credentials.TransportCredentials, error) {
	if err := require(map[string]string{"ca": values.caFile, "cert": values.certFile, "key": values.keyFile}); err != nil {
		return nil, err
	}
	caPEM, err := os.ReadFile(values.caFile)
	if err != nil {
		return nil, fmt.Errorf("read CA: %w", err)
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(caPEM) {
		return nil, errors.New("CA file contains no certificate")
	}
	certificate, err := tls.LoadX509KeyPair(values.certFile, values.keyFile)
	if err != nil {
		return nil, fmt.Errorf("load client certificate: %w", err)
	}
	return credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12, RootCAs: roots, Certificates: []tls.Certificate{certificate}, ServerName: values.serverName}), nil
}

func require(values map[string]string) error {
	for name, value := range values {
		if strings.TrimSpace(value) == "" {
			return fmt.Errorf("--%s is required", name)
		}
	}
	return nil
}

func acceptedDisposition(value conformancev1.AssignmentCommandDisposition) bool {
	return value == conformancev1.AssignmentCommandDisposition_ASSIGNMENT_COMMAND_DISPOSITION_APPLIED || value == conformancev1.AssignmentCommandDisposition_ASSIGNMENT_COMMAND_DISPOSITION_IDEMPOTENT
}

func acceptedAck(value agentv1.OperationContextCommandAck_Status) bool {
	return value == agentv1.OperationContextCommandAck_STATUS_APPLIED || value == agentv1.OperationContextCommandAck_STATUS_ALREADY_APPLIED
}

func square(latitude, longitude, radius float64) []*conformancev1.GeographicPoint {
	return []*conformancev1.GeographicPoint{
		{Latitude: latitude - radius, Longitude: longitude - radius},
		{Latitude: latitude - radius, Longitude: longitude + radius},
		{Latitude: latitude + radius, Longitude: longitude + radius},
		{Latitude: latitude + radius, Longitude: longitude - radius},
		{Latitude: latitude - radius, Longitude: longitude - radius},
	}
}
