import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Retained for background message handling if needed
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // Used to trigger push notifications via backend
import 'widgets/event_detail_card_widget.dart';

class EventScreen extends StatefulWidget {
  final String eventId;
  final String groupId; // Ensure groupId is passed for organization

  const EventScreen({Key? key, required this.eventId, required this.groupId})
      : super(key: key);

  @override
  _EventScreenState createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Removed usage of _firebaseMessaging.send, using http to trigger notifications instead.
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance; 
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isCreating = false;

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
  
  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) {
      print("Validation failed or date/time not selected.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please fill all fields and select a date & time")),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      print("Creating event in Firestore...");
      var eventRef = await _firestore.collection('events').add({
        'title': _titleController.text.trim(),
        'venue': _venueController.text.trim(),
        'datetime': Timestamp.fromDate(_selectedDateTime!),
        'location': _locationController.text.trim(),
        'groupId': widget.groupId, // Associate event with a group
        'players': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("Event successfully created!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event created successfully")),
      );

      // Trigger push notification after event creation via backend.
      //_triggerPushNotification(widget.groupId, _titleController.text.trim());

      Navigator.pop(context);
    } catch (e) {
      print("Error creating event: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating event: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eventId.isEmpty) {
      return _buildEventForm();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('events').doc(widget.eventId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null || !snapshot.data!.exists) {
          return _buildEventForm();
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Event Details')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: EventDetailCardWidget(
              eventId: widget.eventId,
              groupId: widget.groupId, // Pass groupId to the widget
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter event title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(
                  labelText: 'Venue',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter venue' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickDateTime,
                child: Text(
                  _selectedDateTime == null
                      ? 'Select Date & Time'
                      : DateFormat('dd-MM-yyyy HH:mm').format(_selectedDateTime!),
                ),
              ),
              const SizedBox(height: 24),
              _isCreating
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createEvent,
                      child: const Text('Post Event'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}