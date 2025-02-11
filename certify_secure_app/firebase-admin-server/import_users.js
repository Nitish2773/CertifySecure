const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

// Path to your service account key file
const serviceAccount = require("C:/Users/Nitish/Downloads/certify-36ea0-firebase-adminsdk-uekjq-f132a794bb.json");

// Initialize the Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "certify-36ea0.appspot.com",
  databaseURL: "https://certify-36ea0.firebaseio.com",
});

const auth = admin.auth();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Path to your CSV file
const csvFilePath = "C:/CertifySecure/users.csv";

// Error handling
process.on('unhandledRejection', (error) => {
  console.error('Unhandled promise rejection:', error);
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
  process.exit(1);
});

// Read CSV file and process users
const users = [];
fs.createReadStream(csvFilePath)
  .pipe(csv())
  .on('data', (row) => {
    users.push(row);
  })
  .on('end', async () => {
    console.log('CSV file successfully processed');
    console.log(`Total users to process: ${users.length}`);
    await processUsers(users);
  });

async function processUsers(users) {
  for (const [index, user] of users.entries()) {
    const { 
      email, 
      uid, 
      password, 
      role, 
      name, 
      imagePath, 
      department, 
      branch, 
      course, 
      year, 
      semester, 
      designation, 
      company_type, 
      company_location 
    } = user;

    console.log(`Processing user ${index + 1} of ${users.length}: ${email}`);

    try {
      // Check if the user already exists
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(email);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          userRecord = null;
        } else {
          throw error;
        }
      }

      let imageUrl = null;
      if (imagePath) {
        try {
          // Upload image to Firebase Storage
          const uploadResponse = await bucket.upload(imagePath, {
            destination: `faces/${path.basename(imagePath)}`,
            public: true,
            metadata: {
              contentType: 'image/jpeg',
            },
          });

          const file = bucket.file(`faces/${path.basename(imagePath)}`);
          imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(file.name)}?alt=media`;
          console.log(`Successfully uploaded image for ${email}`);
        } catch (error) {
          console.error(`Error uploading image for ${email}:`, error);
        }
      }

      if (userRecord) {
        // Update existing user
        await auth.updateUser(userRecord.uid, {
          uid: uid,
          displayName: name,
          email: email,
          password: password,
        });

        // Update Firestore data based on role
        const userData = {
          email,
          role,
          uid,
          imageUrl,
          department,
          branch,
          course,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (role === 'student') {
          Object.assign(userData, {
            year,
            semester
          });
        } else if (role === 'teacher') {
          Object.assign(userData, {
            designation
          });
        } else if (role === 'company') {
          Object.assign(userData, {
            company_type,
            company_location
          });
        }

        await db.collection('users').doc(uid).set(userData, { merge: true });
        console.log('Successfully updated user data for:', email);

      } else {
        // Create new user
        userRecord = await auth.createUser({
          uid: uid,
          email: email,
          password: password,
          displayName: name,
        });

        // Create Firestore data based on role
        const userData = {
          email,
          role,
          uid,
          imageUrl,
          department,
          branch,
          course,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (role === 'student') {
          Object.assign(userData, {
            year,
            semester
          });
        } else if (role === 'teacher') {
          Object.assign(userData, {
            designation
          });
        } else if (role === 'company') {
          Object.assign(userData, {
            company_type,
            company_location
          });
        }

        await db.collection('users').doc(uid).set(userData);
        console.log('Successfully created new user:', email);
      }
    } catch (error) {
      console.error('Error processing user:', email, error);
    }
  }
  console.log('Finished processing all users');
}